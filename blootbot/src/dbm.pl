#
#      dbm.pl: Extension on the factoid database.
#  OrigAuthor: Kevin Lenzo  (c) 1997
#  CurrAuthor: dms <dms@users.sourceforge.net>
#     Version: v0.6 (20000707)
#   FModified: 19991020
#

use strict;
no strict 'refs';

package main;

use vars qw(%factoids %param);

{
    my %formats = (
	'factoids', [
	    'factoid_key',
	    'requested_by',
	    'requested_time',
	    'requested_count',
	    'created_by',
	    'created_time',
	    'modified_by',
	    'modified_time',
	    'locked_by',
	    'locked_time',
	    'factoid_value'
	],
	'freshmeat', [
	    'projectname_short',
	    'latest_version',
	    'license',
	    'url_homepage',
	    'desc_short'
	],
	'rootwarn', [
	    'nick',
	    'attempt',
	    'time',
	    'host',
	    'channel'
	],
	'seen', [
	    'nick',
	    'time',
	    'channel',
	    'host',
	    'message'
	],
	'stats', [
	    'nick',
	    'type',
	    'channel',
	    'time',
	    'counter'
	],
	'botmail', [
	    'srcwho',
	    'dstwho',
	    'srcuh',
	    'time',
	    'msg'
	]
    );

    sub openDB {
	use DB_File;
	foreach my $table (keys %formats) {
	    next unless (&IsParam($table));

	    my $file = "$param{'DBName'}-$table";

	    if (dbmopen(%{"$table"}, $file, 0666)) {
		&status("Opened DBM $table ($file).");
	    } else {
		&ERROR("Failed open to DBM $table ($file).");
		&shutdown();
		exit 1;
	    }
	}
    }

    sub closeDB {
	foreach my $table (keys %formats) {
	    next unless (&IsParam($table));

	    if (dbmclose(%{ $table })) {
		&status("Closed DBM $table successfully.");
		next;
	    }
	    &ERROR("Failed closing DBM $table.");
	}
    }

    #####
    # Usage: &dbGetColInfo($table);
    sub dbGetColInfo {
	my ($table) = @_;

	if (scalar @{$formats{$table}}) {
	    return @{$formats{$table}};
	} else {
	    &ERROR("dbGCI: no format for table ($table).");
	    return;
	}
    }
}

#####
# Usage: &dbQuote($str);
sub dbQuote {
    return $_[0];
}

#####
# Usage: &dbGet($table, $select, $where);
sub dbGet {
    my ($table, $select, $where) = @_;
    my ($key, $val) = split('=',$where) if $where =~ /=/;
    my $found = 0;
    my @retval;
    my $i;
    &DEBUG("dbGet($table, $select, $where);");
    return unless $key;

    my @format = &dbGetColInfo($table);
    if (!scalar @format) {
	return;
    }

    if (!defined ${ "$table" }{lc $val}) {	# dbm hash exception.
	&DEBUG("dbGet: '$val' does not exist in $table.");
	return;
    }

    # return the whole row.
    if ($select eq "*") {
	@retval = split $;, ${"$table"}{lc $val};
	unshift(@retval,$key);
	return(@retval);
    }

    &DEBUG("dbGet: select=>'$select'.");
    my @array = split "$;", ${"$table"}{lc $val};
    unshift(@array,$val);
    for (0 .. $#format) {
	my $str = $format[$_];
	next unless (grep /^$str$/, split(/\,/, $select));
	$array[$_] ||= '';
	&DEBUG("dG: '$format[$_]'=>'$array[$_]'.");
	push(@retval, $array[$_]);
    }

    if (scalar @retval > 1) {
	return @retval;
    } elsif (scalar @retval == 1) {
	return $retval[0];
    } else {
	return;
    }
}

#####
# Usage: &dbGetCol();
# Usage: &dbGetCol($table, $select, $where, [$type]);
sub dbGetCol {
    my ($table, $select, $where, $type) = @_;
    &FIXME("STUB: &dbGetCol($table, $select, $where, $type);");
}

#####
# Usage: &dbGetColNiceHash($table, $select, $where);
sub dbGetColNiceHash {
    my ($table, $select, $where) = @_;
    &DEBUG("dbGetColNiceHash($table, $select, $where);");
    my ($key, $val) = split('=',$where) if $where =~ /=/;
    return unless ${$table}{lc $val};
    my (%hash) = ();
    $hash{lc $key} = $val;
    my (@format) = &dbGetColInfo($table);
    shift @format;
    @hash{@format} = split $;, ${$table}{lc $val};
    return %hash;
}

#####
# Usage: &dbInsert($table, $primkey, %hash);
#  Note: dbInsert should do dbQuote.
sub dbInsert {
    my ($table, $primkey, %hash) = @_;
    my $found = 0;
    &DEBUG("dbInsert($table, $primkey, ...)");

    my $info = ${$table}{lc $primkey} || '';	# primkey or primval?

    my @format = &dbGetColInfo($table);
    if (!scalar @format) {
	return 0;
    }

    my $i;
    my @array = split $;, $info;
    delete $hash{$format[0]};
    for $i (1 .. $#format) {
	my $col = $format[$i];
	$array[$i - 1]=$hash{$col};
	$array[$i - 1]='' unless $array[$i - 1];
	delete $hash{$col};
	&DEBUG("dbI: '$col'=>'$array[$i - 1]'");
    }

    if (scalar keys %hash) {
	&ERROR("dbI: not added...");
	foreach (keys %hash) {
	    &ERROR("dbI: '$_'=>'$hash{$_}'");
	}
	return 0;
    }

    ${$table}{lc $primkey}	= join $;, @array;

    return 1;
}

sub dbUpdate {
    &FIXME("STUB: &dbUpdate(@_);=>somehow use dbInsert!");
}

#####
# Usage: &dbSetRow($table, @values);
sub dbSetRow {
    &FIXME("STUB: &dbSetRow(@_)");
}

#####
# Usage: &dbDel($table, $primhash_ref);
#  Note: dbDel does dbQuote
sub dbDel {
    my ($table, $phref) = @_;
    # FIXME does not really handle more than one key!
    my $primval = join(':', values %{$phref});

    if (!defined ${$table}{lc $primval}) {
	&DEBUG("dbDel: lc $primval does not exist in $table.");
    } else {
	delete ${$table}{lc $primval};
    }

    return '';
}

#####
# Usage: &dbReplace($table, $key, %hash);
#  Note: dbReplace does optional dbQuote.
sub dbReplace {
    my ($table, $key, %hash) = @_;
    &DEBUG("dbReplace($table, $key, %hash);");

    &dbDel($table, {$key=>$hash{$key}});
    &dbInsert($table, $hash{$key}, %hash);
    return 1;
}

#####
# Usage: &dbSet($table, $primhash_ref, $hash_ref);
sub dbSet {
    my ($table, $phref, $href) = @_;
    &DEBUG("dbSet(@_)");
    my ($key) = keys %{$phref};
    my $where = $key . "=" . $phref->{$key};

    my %hash = &dbGetColNiceHash($table, "*", $where);
    $hash{$key}=$phref->{$key};
    foreach (keys %{$href}) {
	&DEBUG("dbSet: setting $_=${$href}{$_}");
	$hash{$_} = ${$href}{$_};
    }
    &dbReplace($table, $key, %hash);
    return 1;
}

sub dbRaw {
    &FIXME("STUB: &dbRaw(@_);");
}

sub dbRawReturn {
    &FIXME("STUB: &dbRawReturn(@_);");
}



####################################################################
##### Factoid related stuff...
#####

sub countKeys {
    return scalar keys %{$_[0]};
}

sub getKeys {
    &FIXME("STUB: &getKeys(@_); -- REDUNDANT");
}

sub randKey {
    &DEBUG("STUB: &randKey(@_);");
    my ($table, $select) = @_;
    my @format = &dbGetColInfo($table);
    if (!scalar @format) {
	return;
    }

    my $rand = int(rand(&countKeys($table) - 1));
    my @keys = keys %{$table};
    &dbGet($table, '$select', "$format[0]=$keys[$rand]");
}

#####
# Usage: &deleteTable($table);
sub deleteTable {
    my ($table) = @_;
    &FIXME("STUB: deleteTable($table)");
}

##### $select is misleading???
# Usage: &searchTable($table, $returnkey, $primkey, $str);
sub searchTable {
    my ($table, $primkey, $key, $str) = @_;
    &FIXME("STUB: searchTable($table, $primkey, $key, $str)");
    return;
    &DEBUG("searchTable($table, $primkey, $key, $str)");

    if (!scalar &dbGetColInfo($table)) {
	return;
    }   

    my @results;
    foreach (keys %{$table}) {
	my $val = &dbGet($table, "NULL", $_, $key) || '';
	next unless ($val =~ /\Q$str\E/);
	push(@results, $_);
    }

    &DEBUG("sT: ".scalar(@results) );

    @results;
}

#####
# Usage: &getFactInfo($faqtoid, $type);
sub getFactInfo {
    my ($faqtoid, $type) = @_;

    my @format = &dbGetColInfo("factoids");
    if (!scalar @format) {
	return;
    }

    if (!defined $factoids{$faqtoid}) {	# dbm hash exception.
	return;
    }

    if ($type eq "*") {		# all.
	return split /$;/, $factoids{$faqtoid};
    }

    # specific.
    if (!grep /^$type$/, @format) {
	&ERROR("gFI: type '$type' not valid for factoids.");
	return;
    }

    my @array	= split /$;/, $factoids{$faqtoid};
    for (0 .. $#format) {
	next unless ($type eq $format[$_]);
	return $array[$_];
    }

    &ERROR("gFI: should never happen.");
}   

#####
# Usage: &getFactoid($faqtoid);
sub getFactoid {
    my ($faqtoid) = @_;

    if (!defined $faqtoid or $faqtoid =~ /^\s*$/) {
	&WARN("getF: faqtoid == NULL.");
	return;
    }

    if (defined $factoids{$faqtoid}) {	# dbm hash exception.
	# we assume 1 unfortunately.
	### TODO: use &getFactInfo() instead?
	my $retval = (split $;, $factoids{$faqtoid})[1];

	if (defined $retval) {
	    &DEBUG("getF: returning '$retval' for '$faqtoid'.");
	} else {
	    &DEBUG("getF: returning NULL for '$faqtoid'.");
	}
	return $retval;
    } else {
	return;
    }
}

#####
# Usage: &delFactoid($faqtoid);
sub delFactoid {
    my ($faqtoid) = @_;

    if (!defined $faqtoid or $faqtoid =~ /^\s*$/) {
	&WARN("delF: faqtoid == NULL.");
	return;
    }

    if (defined $factoids{$faqtoid}) {	# dbm hash exception.
	delete $factoids{$faqtoid};
	&status("DELETED $faqtoid");
    } else {
	&WARN("delF: nothing to deleted? ($faqtoid)");
	return;
    }
}

sub checkTables {
# nothing - DB_FIle will create them on openDB()
}

1;
