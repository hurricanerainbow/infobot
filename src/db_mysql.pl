#
# db_mysql.pl: MySQL database frontend.
#      Author: dms
#     Version: v0.2c (19991224)
#     Created: 19991203
#

package main;

if (&IsParam("useStrict")) { use strict; }

sub openDB {
    my ($db, $user, $pass) = @_;
    my $dsn = "DBI:mysql:$db:$param{'SQLHost'}";
    $dbh    = DBI->connect($dsn, $user, $pass);

    if ($dbh) {
	&status("Opened MySQL connection to $param{'SQLHost'}");
    } else {
	&ERROR("cannot connect to $param{'SQLHost'}.");
	&ERROR("since mysql is not available, shutting down bot!");
	&shutdown();
	&closePID();
	exit 1;
    }
}

sub closeDB {
    return 0 unless ($dbh);

    &status("Closed MySQL connection to $param{'SQLHost'}.");
    $dbh->disconnect();
    return 1;
}

#####
# Usage: &dbQuote($str);
sub dbQuote {
    return $dbh->quote($_[0]);
}

#####
# Usage: &dbGet($table, $select, $where);
sub dbGet {
    my ($table, $select, $where) = @_;
    my $query	 = "SELECT $select FROM $table";
    $query	.= " WHERE $where" if ($where);

    if (!defined $select) {
	&WARN("dbGet: select == NULL. table => $table");
	return;
    }

    my $sth;
    if (!($sth = $dbh->prepare($query))) {
	&ERROR("Get: prepare: $DBI::errstr");
	return;
    }

    &SQLDebug($query);
    if (!$sth->execute) {
	&ERROR("Get: execute: '$query'");
	$sth->finish;
	return 0;
    }

    my @retval = $sth->fetchrow_array;

    $sth->finish;

    if (scalar @retval > 1) {
	return @retval;
    } elsif (scalar @retval == 1) {
	return $retval[0];
    } else {
	return;
    }
}

#####
# Usage: &dbGetCol($table, $select, $where, [$type]);
sub dbGetCol {
    my ($table, $select, $where, $type) = @_;
    my $query	= "SELECT $select FROM $table";
    $query	.= " WHERE ".$where if ($where);
    my %retval;

    &DEBUG("dbGetCol: query => '$query'.");

    my $sth = $dbh->prepare($query);
    &SQLDebug($query);
    if (!$sth->execute) {
	&ERROR("GetCol: execute: '$query'");
#	&ERROR("GetCol => $DBI::errstr");
	$sth->finish;
	return;
    }

    if (defined $type and $type == 2) {
	&DEBUG("dbgetcol: type 2!");
	while (my @row = $sth->fetchrow_array) {
	    $retval{$row[0]} = join(':', $row[1..$#row]);
	}
	&DEBUG("dbgetcol: count => ".scalar(keys %retval) );

    } elsif (defined $type and $type == 1) {
	while (my @row = $sth->fetchrow_array) {
	    # reverse it to make it easier to count.
	    if (scalar @row == 2) {
		$retval{$row[1]}{$row[0]} = 1;
	    } elsif (scalar @row == 3) {
		$retval{$row[1]}{$row[0]} = 1;
	    }
	    # what to do if there's only one or more than 3?
	}

    } else {
	while (my @row = $sth->fetchrow_array) {
	    $retval{$row[0]} = $row[1];
	}
    }

    $sth->finish;

    return %retval;
}

####
# Usage: &dbGetColInfo($table);
sub dbGetColInfo {
    my ($table) = @_;

    my $query = "SHOW COLUMNS from $table";
    my %retval;

    my $sth = $dbh->prepare($query);
    &SQLDebug($query);
    if (!$sth->execute) {
	&ERROR("GRI => '$query'");
	&ERROR("GRI => $DBI::errstr");
	$sth->finish;
	return;
    }

    my @cols;
    while (my @row = $sth->fetchrow_array) {
	push(@cols, $row[0]);
    }
    $sth->finish;

    return @cols;
}

#####
# Usage: &dbSet($table, $primhash_ref, $hash_ref);
sub dbSet {
    my ($table, $phref, $href) = @_;
    my $where = join(' AND ', map {
		$_."=".&dbQuote($phref->{$_})
	} keys %{$phref}
    );

    my $result = &dbGet($table, join(',', keys %{$phref}), $where);

    my(@keys,@vals);
    foreach (keys %{$href}) {
	push(@keys, $_);
	push(@vals, &dbQuote($href->{$_}) );
    }

    if (!@keys or !@vals) {
	&WARN("dbset: keys or vals is NULL.");
	return;
    }

    my $query;
    if (defined $result) {
	my @keyval;
	for(my$i=0; $i<scalar @keys; $i++) {
	    push(@keyval, $keys[$i]."=".$vals[$i] );
	}

	$query = "UPDATE $table SET ".
		join(' AND ', @keyval).
		" WHERE ".$where;
    } else {
	foreach (keys %{$phref}) {
	    push(@keys, $_);
	    push(@vals, &dbQuote($phref->{$_}) );
	}

	$query = sprintf("INSERT INTO $table (%s) VALUES (%s)",
		join(',',@keys), join(',',@vals) );
    }

    &dbRaw("Set", $query);

    return 1;
}

#####
# Usage: &dbUpdate($table, $primkey, $primval, %hash);
sub dbUpdate {
    my ($table, $primkey, $primval, %hash) = @_;
    my (@array);

    foreach (keys %hash) {
	push(@array, "$_=".&dbQuote($hash{$_}) );
    }

    &dbRaw("Update", "UPDATE $table SET ".join(', ', @array).
		" WHERE $primkey=".&dbQuote($primval)
    );

    return 1;
}

#####
# Usage: &dbInsert($table, $primkey, %hash);
sub dbInsert {
    my ($table, $primkey, %hash, $delay) = @_;
    my (@keys, @vals);
    my $p	= "";

    if ($delay) {
	&DEBUG("dbI: delay => $delay");
	$p	= " DELAYED";
    }

    foreach (keys %hash) {
	push(@keys, $_);
	push(@vals, &dbQuote($hash{$_}));
    }

    &dbRaw("Insert($table)", "INSERT $p INTO $table (".join(',',@keys).
		") VALUES (".join(',',@vals).")"
    );

    return 1;
}

#####
# Usage: &dbReplace($table, %hash);
sub dbReplace {
    my ($table, %hash) = @_;
    my (@keys, @vals);

    foreach (keys %hash) {
	if (s/^-//) {	# as is.
	    push(@keys, $_);
	    push(@vals, $hash{'-'.$_});
	} else {
	    push(@keys, $_);
	    push(@vals, &dbQuote($hash{$_}));
	}
    }

    if (0) {
	&DEBUG("REPLACE INTO $table (".join(',',@keys).
		") VALUES (". join(',',@vals). ")" );
    }

    &dbRaw("Replace($table)", "REPLACE INTO $table (".join(',',@keys).
		") VALUES (". join(',',@vals). ")"
    );

    return 1;
}

#####
# Usage: &dbSetRow($table, @values);
sub dbSetRow ($@$) {
    my ($table, @values, $delay) = @_;
    my $p	= ($delay) ? " DELAYED " : "";

    foreach (@values) {
	$_ = &dbQuote($_);
    }

    return &dbRaw("SetRow", "INSERT $p INTO $table VALUES (".
	join(",", @values) .")" );
}

#####
# Usage: &dbDel($table, $primkey, $primval, [$key]);
sub dbDel {
    my ($table, $primkey, $primval, $key) = @_;

    &dbRaw("Del", "DELETE FROM $table WHERE $primkey=".
		&dbQuote($primval)
    );

    return 1;
}

# Usage: &dbRaw($prefix,$rawquery);
sub dbRaw {
    my ($prefix,$query) = @_;
    my $sth;

    if (!($sth = $dbh->prepare($query))) {
	&ERROR("Raw($prefix): $DBI::errstr");
	return 0;
    }

#    &DEBUG("query => '$query'.");

    &SQLDebug($query);
    if (!$sth->execute) {
	&ERROR("Raw($prefix): => '$query'");
	# $DBI::errstr is printed as warning automatically.
	$sth->finish;
	return 0;
    }

    $sth->finish;

    return 1;
}

# Usage: &dbRawReturn($rawquery);
sub dbRawReturn {
    my ($query) = @_;
    my @retval;

    my $sth = $dbh->prepare($query);
    &SQLDebug($query);
    &ERROR("RawReturn => '$query'.") unless $sth->execute;
    while (my @row = $sth->fetchrow_array) {
	push(@retval, $row[0]);
    }
    $sth->finish;

    return @retval;
}

####################################################################
##### Misc DBI stuff...
#####

#####
# Usage: &countKeys($table, [$col]);
sub countKeys {
    my ($table, $col) = @_;
    $col ||= "*";

    return (&dbRawReturn("SELECT count($col) FROM $table"))[0];
}

# Usage: &sumKey($table, $col);
sub sumKey {
    my ($table, $col) = @_;

    return (&dbRawReturn("SELECT sum($col) FROM $table"))[0];
}

##### NOT USED.
# Usage: &getKeys($table,$primkey);
sub getKeys {
    my ($table,$primkey) = @_;
    my @retval;

    my $query	= "SELECT $primkey FROM $table";
    my $sth	= $dbh->prepare($query);

    &SQLDebug($query);
    &WARN("ERROR: getKeys($query)") unless $sth->execute;

    while (my @row = $sth->fetchrow_array) {
	push(@retval, $row[0]);
    }
    $sth->finish;

    return @retval;
}

#####
# Usage: &randKey($table, $select);
sub randKey {
    my ($table, $select) = @_;
    my $rand	= int(rand(&countKeys($table) - 1));
    my $query	= "SELECT $select FROM $table LIMIT $rand,1";

    my $sth	= $dbh->prepare($query);
    &SQLDebug($query);
    &WARN("randKey($query)") unless $sth->execute;
    my @retval	= $sth->fetchrow_array;
    $sth->finish;

    return @retval;
}

#####
# Usage: &deleteTable($table);
sub deleteTable {
    &dbRaw("deleteTable($_[0])", "DELETE FROM $_[0]");
}

# Usage: &searchTable($table, $select, $key, $str);
sub searchTable {
    my($table, $select, $key, $str) = @_;
    my $origStr = $str;
    my @results;

    # allow two types of wildcards.
    if ($str =~ /^\^(.*)\$$/) {
	&DEBUG("searchTable: should use dbGet(), heh.");
	$str = $1;
    } else {
	$str .= "%"	if ($str =~ s/^\^//);
	$str = "%".$str if ($str =~ s/\$$//);
	$str = "%".$str."%" if ($str eq $origStr);	# el-cheapo fix.
    }

    $str =~ s/\_/\\_/g;
    $str =~ s/\?/\_/g;	# '.' should be supported, too.
    # end of string fix.

    my $query = "SELECT $select FROM $table WHERE $key LIKE ". 
		&dbQuote($str);
    my $sth = $dbh->prepare($query);
    &SQLDebug($query);
    &WARN("Search($query)") unless $sth->execute;

    while (my @row = $sth->fetchrow_array) {
	push(@results, $row[0]);
    }
    $sth->finish;

    return @results;
}

####################################################################
##### Factoid related stuff...
#####

#####
# Usage: &getFactInfo($faqtoid, type);
sub getFactInfo {
    return &dbGet("factoids", $_[1], "factoid_key='$_[0]'");
}

#####
# Usage: &getFactoid($faqtoid);
sub getFactoid {
    return &getFactInfo($_[0], "factoid_value");
}

#####
# Usage: &delFactoid($faqtoid);
sub delFactoid {
    my ($faqtoid) = @_;

    &dbDel("factoids", "factoid_key",$faqtoid);
    &status("DELETED '$faqtoid'");

    return 1;
}

sub SQLDebug {
    return unless (&IsParam("SQLDebug"));

    return if (!fileno SQLDEBUG);

    print SQLDEBUG $_[0]."\n";
}

sub dbCreateTable {
    my($table)	= @_;
    my(@path)	= (".","..","../..");
    my $found	= 0;
    my $data;

    foreach (@path) {
	my $file = "$_/setup/$table.sql";
	&DEBUG("dbCT: file => $file");
	next unless ( -f $file );

	&DEBUG("found!!!");

	open(IN, $file);
	while (<IN>) {
	    chop;
	    $data .= $_;
	}

	$found++;
	last;
    }

    if (!$found) {
	return 0;
    } else {
	&dbRaw("create($table)", $data);
	return 1;
    }
}

sub checkTables {
    my $database_exists = 0;
    foreach (&dbRawReturn("SHOW DATABASES")) {
	$database_exists++ if ($_ eq $param{'DBName'});
    }

    unless ($database_exists) {
	&status("Creating database $param{DBName}...");
	$query = "CREATE DATABASE $param{DBName}";
	&dbRaw("create(db $param{DBName})", $query);
    }

    # retrieve a list of db's from the server.
    my %db;
    foreach ($dbh->func('_ListTables')) {
	$db{$_} = 1;
    }

    # create database.
    if (!scalar keys %db) {
#	&status("Creating database $param{'DBName'}...");
#	$query = "CREATE DATABASE $param{'DBName'}";
#	&dbRaw("create(db $param{'DBName'})", $query);
    }

    foreach ("factoids", "freshmeat", "rootwarn", "seen", "stats",
    ) {
	next if (exists $db{$_});
	&status("  creating new table $_...");

	&dbCreateTable($_);
    }
}

1;
