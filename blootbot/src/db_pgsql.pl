#
# db_pgsql.pl: PostgreSQL database frontend.
#      Author: dms
#     Version: v0.2 (20010908)
#     Created: 20000629
#

if (&IsParam("useStrict")) { use strict; }

sub openDB {
    my $connectstr="dbi:Pg:dbname=$param{DBName};";
    $connectstr.=";host=$param{SQLHost}" if(defined $param{'SQLHost'});
    $dbh = DBI->connect($connectstr, $param{'SQLUser'}, $param{'SQLPass'});

    if (!$dbh->err) {
	&status("Opened pgSQL connection".
		(exists $param{'SQLHost'} ? " to ".$param{'SQLHost'} : ""));
    } else {
	&ERROR("cannot connect to $param{'SQLHost'}.");
	&ERROR("pgSQL: ".$dbh->errstr);

	&closePID();
	&closeSHM($shm);
	&closeLog();

	exit 1;
    }
}

sub closeDB {
    return 0 unless ($dbh);

    &status("Closed pgSQL connection.");
    $dbh->disconnect();

    return 1;
}

#####
# Usage: &dbQuote($str);
sub dbQuote {
    return $dbh->quote($_[0]);

    $_ = $_[0];
    s/'/\\'/g;
    return "'$_'";
}

#####
# Usage: &dbGet($table, $select, $where);
sub dbGet {
    my ($table, $select, $where) = @_;
    my $query	= "SELECT $select FROM $table";
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

    my $sth = $dbh->prepare($query);
    &SQLDebug($query);
    if (!$sth->execute) {
	&ERROR("GetCol: execute: '$query'");
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

#####
# Usage: &dbGetColNiceHash($table, $select, $where);
sub dbGetColNiceHash {
    my ($table, $select, $where) = @_;
    $select	||= "*";
    my $query	= "SELECT $select FROM $table";
    $query	.= " WHERE ".$where if ($where);
    my %retval;

    &DEBUG("dbGetColNiceHash: query => '$query'.");

    my $sth = $dbh->prepare($query);
    &SQLDebug($query);
    if (!$sth->execute) {
	&ERROR("GetColNiceHash: execute: '$query'");
#	&ERROR("GetCol => $DBI::errstr");
	$sth->finish;
	return;
    }

    %retval = %{ $sth->fetchrow_hashref() };
    $sth->finish;

    return %retval;
}

####
# Usage: &dbGetColInfo($table);
sub dbGetColInfo {
    my ($table) = @_;

    my $query = "SELECT * FROM $table LIMIT 1;";
#    my $query = "SHOW COLUMNS from $table";
    my %retval;

    my $sth = $dbh->prepare($query);
    &SQLDebug($query);
    if (!$sth->execute) {
	&ERROR("GRI => '$query'");
	&ERROR("GRI => $DBI::errstr");
	$sth->finish;
	return;
    }

    %retval = %{ $sth->fetchrow_hashref() };
    $sth->finish;

    return keys %retval;
}

#####
# Usage: &dbSet($table, $primhash_ref, $hash_ref);
#  Note: dbSet does dbQuote.
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
		" WHERE $where";
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
# Usage: &dbInsert($table, $primkey, $primval, %hash);
sub dbInsert {
    my ($table, $primkey, $primval, %hash) = @_;
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
# Usage: &dbReplace($table, $key, %hash);
#  Note: dbReplace does optional dbQuote.
sub dbReplace {
    my ($table, $key, %hash) = @_;
    my (@keys, @vals);
    my $where	= "WHERE $key=".&dbQuote($hash{$key});
    my $squery	= "SELECT $key FROM $table $where;";
    my $iquery	= "INSERT INTO $table ";
    my $uquery	= "UPDATE $table SET ";

    foreach (keys %hash) {
	if (s/^-//) {   # as is.
	    push(@keys, $_);
	    push(@vals, $hash{'-'.$_});
	} else {
	    push(@keys, $_);
	    push(@vals, &dbQuote($hash{$_}));
	}
	$uquery .= "$keys[-1] = $vals[-1], ";
    }
    $uquery =~ s/, $/ $where;/;
    $iquery .= "(". join(',',@keys) .") VALUES (". join(',',@vals) .");";

    &DEBUG($squery) if (0);

    if(&dbRawReturn($squery)) {
	&dbRaw("Replace($table)", $uquery);
    } else {
	&dbRaw("Replace($table)", $iquery);
     }


    return 1;
}

##### MADE REDUNDANT BY LEAR.
# Usage: &dbSetRow($table, $vref, $delay);
#  Note: dbSetRow does dbQuote.
sub dbSetRow ($@$) {
    my ($table, $vref, $delay) = @_;
    my $p      = ($delay) ? " DELAYED " : "";

    # see 'perldoc perlreftut'
    my @values;
    foreach (@{ $vref }) {
	push(@values, &dbQuote($_) );
    }

    if (!scalar @values) {
	&WARN("dbSetRow: values array == NULL.");
	return;
    }

    return &dbRaw("SetRow", "INSERT $p INTO $table VALUES (".
	join(",", @values) .")" );
}

#####
# Usage: &dbDel($table, $primkey, $primval, [$key]);
#  Note: dbDel does dbQuote
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

#####
# Usage: &randKey($table, $select);
sub randKey {
    my ($table, $select) = @_;
    my $rand	= int(rand(&countKeys($table) - 1));
    my $query	= "SELECT $select FROM $table LIMIT 1,$rand";

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

#####
# Usage: &searchTable($table, $select, $key, $str);
#  Note: searchTable does dbQuote.
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
    if (!$sth->execute) {
	&WARN("Search($query)");
	return;
    }

    while (my @row = $sth->fetchrow_array) {
	push(@results, $row[0]);
    }
    $sth->finish;

    return @results;
}

#####
#
sub checkTables {
    &FIXME("pgsql: checkTables(@_);");
    return 1;
}

1;
