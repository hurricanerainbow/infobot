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
	&shutdown();
	&closePID();
	exit 1;
    }
}

sub closeDB {
    if (!$dbh) {
	&WARN("closeDB: connection already closed?");
	return 0;
    }

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
# Usage: &dbGet($table, $primkey, $primval, $select);
sub dbGet {
    my ($table, $primkey, $primval, $select) = @_;
    my $query = "SELECT $select FROM $table WHERE $primkey=". 
		&dbQuote($primval);

    my $sth;
    if (!($sth = $dbh->prepare($query))) {
	&ERROR("Get: $DBI::errstr");
	return;
    }

    &SQLDebug($query);
    if (!$sth->execute) {
	&ERROR("Get => '$query'");
	&ERROR("Get => $DBI::errstr");
	return;
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
# Usage: &dbGetCol($table, $primkey, $key, [$type]);
sub dbGetCol {
    my ($table, $primkey, $key, $type) = @_;
    my $query = "SELECT $primkey,$key FROM $table WHERE $key IS NOT NULL";
    my %retval;

    my $sth = $dbh->prepare($query);
    &SQLDebug($query);
    if (!$sth->execute) {
	&ERROR("GetCol => '$query'");
	&ERROR("GetCol => $DBI::errstr");
	return;
    }

    if (defined $type and $type == 1) {
	while (my @row = $sth->fetchrow_array) {
	    # reverse it to make it easier to count.
	    $retval{$row[1]}{$row[0]} = 1;
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
# Usage: &dbGetRowInfo($table);
sub dbGetRowInfo {
    my ($table) = @_;

    my $query = "SHOW COLUMNS from $table";
    my %retval;

    my $sth = $dbh->prepare($query);
    &SQLDebug($query);
    if (!$sth->execute) {
	&ERROR("GRI => '$query'");
	&ERROR("GRI => $DBI::errstr");
    }

    my @cols;
    while (my @row = $sth->fetchrow_array) {
	push(@cols, $row[0]);
    }
    $sth->finish;

    return @cols;
}

#####
# Usage: &dbSet($table, $primkey, $primval, $key, $val);
sub dbSet {
    my ($table, $primkey, $primval, $key, $val) = @_;
    my $query;

    my $result = &dbGet($table,$primkey,$primval,$primkey);
    if (defined $result) {
	$query = "UPDATE $table SET $key=".&dbQuote($val).
		" WHERE $primkey=".&dbQuote($primval);
    } else {
	$query = "INSERT INTO $table ($primkey,$key) VALUES (".
		&dbQuote($primval).",".&dbQuote($val).")";
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
    my ($table, $primkey, %hash) = @_;
    my (@keys, @vals);

    foreach (keys %hash) {
	push(@keys, $_);
	push(@vals, &dbQuote($hash{$_}));
    }

    &dbRaw("Insert($table)", "INSERT INTO $table (".join(',',@keys).
		") VALUES (".join(',',@vals).")"
    );

    return 1;
}

#####
# Usage: &dbSetRow($table, @values);
sub dbSetRow {
    my ($table, @values) = @_;

    foreach (@values) {
	$_ = &dbQuote($_);
    }

    return &dbRaw("SetRow", "INSERT INTO $table VALUES (".
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

    &SQLDebug($query);
    if (!$sth->execute) {
	&ERROR("Raw($prefix): => '$query'");
	&ERROR("Raw($prefix): $DBI::errstr");
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
# Usage: &countKeys($table);
sub countKeys {
    my ($table) = @_;

    return (&dbRawReturn("SELECT count(*) FROM $table"))[0];
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
    return &dbGet("factoids", "factoid_key", $_[0], $_[1]);
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
    &status("DELETED $faqtoid");

    return 1;
}

sub SQLDebug {
    return unless (&IsParam("SQLDebug"));

    return if (!fileno SQLDEBUG);

    print SQLDEBUG $_[0]."\n";
}

1;
