#
#   db_dbm.pl: Extension on the factoid database.
#  OrigAuthor: Kevin Lenzo  (c) 1997
#  CurrAuthor: dms <dms@users.sourceforge.net>
#     Version: v0.6 (20000707)
#   FModified: 19991020
#

package main;

if (&IsParam("useStrict")) { use strict; }

use vars qw(%factoids %freshmeat %seen %rootwarn);	# db hash.
use vars qw(@factoids_format @rootwarn_format @seen_format);

@factoids_format = (
	"factoid_key",
	"factoid_value",
	"created_by",
	"created_time",
	"modified_by",
	"modified_time",
	"requested_by",
	"requested_time",
	"requested_count",
	"locked_by",
	"locked_time"
);

@freshmeat_format = (
	"name",
	"stable",
	"devel",
	"section",
	"license",
	"homepage",
	"download",
	"changelog",
	"deb",
	"rpm",
	"link",
	"oneliner",
);

@rootwarn_format = ("nick", "attempt", "time", "host", "channel");

@seen_format = (
	"nick",
	"time",
	"channel",
	"host",
	"messagecount",
	"hehcount",
	"karma",
	"message"
);

@stats_format = (
	"nick",
	"type",
	"counter",
	"time"
);

my @dbm	= ("factoids","freshmeat","rootwarn","seen","stats");

sub openDB {
    use DB_File;
    foreach (@dbm) {
	next unless (&IsParam($_));

	my $file = "$param{'DBName'}-$_";

	if (dbmopen(%{ $_ }, $file, 0666)) {
	    &status("Opened DBM $_ ($file).");
	} else {
	    &ERROR("Failed open to DBM $_ ($file).");
	    &shutdown();
	    exit 1;
	}
    }
}

sub closeDB {

    foreach (@dbm) {
	next unless (&IsParam($_));

	if (dbmclose(%{ $_ })) {
	    &status("Closed DBM $_ successfully.");
	    next;
	}
	&ERROR("Failed closing DBM $_.");
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

    if (!scalar @{ "${table}_format" }) {
	&ERROR("dG: no valid format layout for $table.");
	return;
    }

    if (!defined ${ "$table" }{lc $val}) {	# dbm hash exception.
	&DEBUG("dbGet: '$val' does not exist in $table.");
	return;
    }

    # return the whole row.
    if ($select eq "*") {
	return split $;, ${ "$table" }{lc $val};
    } else {
	&DEBUG("dbGet: select => '$select'.");
    }

    my @array = split "$;", ${ "$table" }{lc $val};
    for (0 .. $#{ "${table}_format" }) {
	my $str = ${ "${table}_format" }[$_];
	next unless (grep /^$str$/, split(/\,/, $select));

	$array[$_] ||= '';
	&DEBUG("dG: pushing '$array[$_]'.");
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
    my (%hash) = ();
    return unless ${$table}{lc $val};
    @hash{@{"${table}_format"}} = split $;, ${$table}{lc $val};
    return %hash;
}

#####
# Usage: &dbGetColInfo();
sub dbGetColInfo {
    my ($table) = @_;

    if (scalar @{ "${table}_format" }) {
	return @{ "${table}_format" };
    } else {
	&ERROR("dbGCI: invalid format name ($table) [${table}_format].");
	return;
    }
}

#####
# Usage: &dbInsert($table, $primkey, %hash);
#  Note: dbInsert should do dbQuote.
sub dbInsert {
    my ($table, $primkey, %hash) = @_;
    my $found = 0;
    &DEBUG("dbInsert($table, $primkey, ...)");

    my $info = ${$table}{lc $primkey} || '';	# primkey or primval?

    if (!scalar @{ "${table}_format" }) {
	&ERROR("dbI: array ${table}_format does not exist.");
	return 0;
    }

    my $i;
    my @array = split $;, $info;
    $array[0]=$primkey;
    delete $hash{${ "${table}_format" }[0]};
    for $i (1 .. $#{ "${table}_format" }) {
	my $col = ${ "${table}_format" }[$i];
	$array[$i]=$hash{$col};
	$array[$i]='' unless $array[$i];
	delete $hash{$col};
	&DEBUG("dbI: setting $table->$primkey\{$col\} => '$array[$i]'.");
    }

    if (scalar keys %hash) {
	&ERROR("dbI: not added...");
	foreach (keys %hash) {
	    &ERROR("dbI:   '$_' => '$hash{$_}'");
	}
	return 0;
    }

    ${$table}{lc $primkey}	= join $;, @array;

    return 1;
}

sub dbUpdate {
    &FIXME("STUB: &dbUpdate(@_); => somehow use dbInsert!");
}

#####
# Usage: &dbSetRow($table, @values);
sub dbSetRow {
    my ($table, @values) = @_;
    &DEBUG("dbSetRow(@_);");
    my $key = lc $values[0];

    if (!scalar @{ "${table}_format" }) {
	&ERROR("dbSR: array ${table}_format does not exist.");
	return 0;
    }

    if (defined ${$table}{$key}) {
	&WARN("dbSetRow: $table {$key} already exists?");
    }

    if (scalar @values != scalar @{ "${table}_format" }) {
	&WARN("dbSetRow: scalar values != scalar ${table}_format.");
    }

    for (0 .. $#{ "${table}_format" }) {
	if (defined $array[$_] and $array[$_] ne "") {
	    &DEBUG("dbSetRow: array[$_] != NULL($array[$_]).");
	}
	$array[$_] = $values[$_];
    }

    ${$table}{$key}	= join $;, @array;
}

#####
# Usage: &dbDel($table, $primkey, $primval, [$key]);
sub dbDel {
    my ($table, $primkey, $primval, $key) = @_;
    &DEBUG("dbDel($table, $primkey, $primval);");

    if (!scalar @{ "${table}_format" }) {
	&ERROR("dbD: array ${table}_format does not exist.");
	return 0;
    }

    if (!defined ${$table}{lc $primval}) {
	&WARN("dbDel: lc $primval does not exist in $table.");
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

    &dbDel($table, $key, $hash{$key}, %hash);
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
    &FIXME("STUB: &randKey(@_);");
}

##### $select is misleading???
# Usage: &searchTable($table, $returnkey, $primkey, $str);
sub searchTable {
    &FIXME("STUB: searchTable($table, $primkey, $key, $str)");
    return;
    my ($table, $primkey, $key, $str) = @_;
    &DEBUG("searchTable($table, $primkey, $key, $str)");

    if (!scalar @{ "${table}_format" }) {
	&ERROR("sT: no valid format layout for $table.");
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
# Usage: &getFactInfo($faqtoid, type);
sub getFactInfo {
    my ($faqtoid, $type) = @_;

    if (!defined $factoids{$faqtoid}) {	# dbm hash exception.
	return;
    }

    if ($type eq "*") {		# all.
	return split /$;/, $factoids{$faqtoid};
    }

    # specific.
    if (!grep /^$type$/, @factoids_format) {
	&ERROR("gFI: type '$type' not valid for factoids.");
	return;
    }

    my @array	= split /$;/, $factoids{$faqtoid};
    for (0 .. $#factoids_format) {
	next unless ($type eq $factoids_format[$_]);
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
