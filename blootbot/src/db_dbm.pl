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

my @dbm	= ("factoids","freshmeat","rootwarn","seen");

sub openDB {

    foreach (@dbm) {
	next unless (&IsParam($_));

	my $file = "$param{'DBName'}-$_";

	if (dbmopen(%{ $_ }, $file, 0644)) {
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
# Usage: &dbGet($table, $primkey, $primval, $select);
sub dbGet {
    my ($db, $key, $val, $select) = @_;
    my $found = 0;
    my @retval;
    my $i;
    &DEBUG("dbGet($db, $key, $val, $select);");

    if (!scalar @{ "${db}_format" }) {
	&ERROR("dG: no valid format layout for $db.");
	return;
    }

    if (!defined ${ "$db" }{lc $val}) {	# dbm hash exception.
	&DEBUG("dbGet: '$val' does not exist in $db.");
	return;
    }

    # return the whole row.
    if ($select eq "*") {
	return split $;, ${ "$db" }{lc $val};
    } else {
	&DEBUG("dbGet: select => '$select'.");
    }

    my @array = split "$;", ${ "$db" }{lc $val};
    for (0 .. $#{ "${db}_format" }) {
	my $str = ${ "${db}_format" }[$_];
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
sub dbGetCol {
    &DEBUG("STUB: &dbGetCol();");
}

#####
# Usage: &dbGetRowInfo();
sub dbGetRowInfo {
    my ($db) = @_;

    if (scalar @{ "${db}_format" }) {
	return @{ "${db}_format" };
    } else {
	&ERROR("dbGCI: invalid format name ($db) [${db}_format].");
	return;
    }
}

#####
# Usage: &dbSet($db, $primkey, $primval, $key, $val);
sub dbSet {
    my ($db, $primkey, $primval, $key, $val) = @_;
    my $found = 0;
    &DEBUG("dbSet($db, $primkey, $primval, $key, $val);");

    my $info = ${$db}{lc $primval};	# case insensitive.
    my @array = ($info) ? split(/$;/, $info) : ();

    # new entry.
    if (!defined ${$db}{lc $primval}) {
	# we assume primary key as first one. bad!
	$array[0] = $primval;		# case sensitive.
    }

    for (0 .. $#{ "${db}_format" }) {
	$array[$_] ||= '';	# from undefined to ''.
	next unless (${ "${db}_format" }[$_] eq $key);
	&DEBUG("dbSet: Setting array[$_]($key) to '$val'.");
	$array[$_] = $val;
	$found++;
	last;
    }

    if (!$found) {
	&msg($who,"error: invalid element name \002$type\002.");
	return 0;
    }

    &DEBUG("setting $primval => '".join('|', @array)."'.");
    ${$db}{lc $primval}	= join $;, @array;

    return 1;
}

sub dbUpdate {
    &DEBUG("STUB: &dbUpdate(@_); FIXME!!!");
}

sub dbInsert {
    my ($db, $primkey, %hash) = @_;
    my $found = 0;

    my $info = ${$db}{lc $primkey} || '';	# primkey or primval?

    if (!scalar @{ "${db}_format" }) {
	&ERROR("dbI: array ${db}_format does not exist.");
	return 0;
    }

    my $i;
    my @array = split $;, $info;
    for $i (0 .. $#{ "${db}_format" }) {
	$array[$i] ||= '';

	foreach (keys %hash) {
	    my $col = ${ "${db}_format" }[$i];
	    next unless ($col eq $_);

	    &DEBUG("dbI: setting $db->$primkey\{$col} => '$hash{$_}'.");
	    $array[$i] = $hash{$_};
	    delete $hash{$_};
	}
    }

    if (scalar keys %hash) {
	&ERROR("dbI: not added...");
	foreach (keys %hash) {
	    &ERROR("dbI:   '$_' => '$hash{$_}'");
	}
	return 0;
    }

    ${$db}{lc $primkey}	= join $;, @array;

    return 1;
}

#####
# Usage: &dbSetRow($db, @values);
sub dbSetRow {
    my ($db, @values) = @_;
    my $key = lc $values[0];

    if (!scalar @{ "${db}_format" }) {
	&ERROR("dbSR: array ${db}_format does not exist.");
	return 0;
    }

    if (defined ${$db}{$key}) {
	&WARN("dbSetRow: $db {$key} already exists?");
    }

    if (scalar @values != scalar @{ "${db}_format" }) {
	&WARN("dbSetRow: scalar values != scalar ${db}_format.");
    }

    for (0 .. $#{ "${db}_format" }) {
	if (defined $array[$_] and $array[$_] ne "") {
	    &DEBUG("dbSetRow: array[$_] != NULL($array[$_]).");
	}
	$array[$_] = $values[$_];
    }

    ${$db}{$key}	= join $;, @array;

    &DEBUG("STUB: &dbSetRow(@_);");
}

#####
# Usage: &dbDel($db, NULL, $primval);
sub dbDel {
    my ($db, $primkey, $primval) = @_;

    if (!scalar @{ "${db}_format" }) {
	&ERROR("dbD: array ${db}_format does not exist.");
	return 0;
    }

    if (!defined ${$db}{lc $primval}) {
	&WARN("dbDel: lc $primval does not exist in $db.");
    } else {
	delete ${$db}{lc $primval};
    }

    return '';
}

sub dbRaw {
    &DEBUG("STUB: &dbRaw(@_);");
}

sub dbRawReturn {
    &DEBUG("STUB: &dbRawReturn(@_);");
}



####################################################################
##### Factoid related stuff...
#####

sub countKeys {
    return scalar keys %{$_[0]};
}

sub getKeys {
    &DEBUG("STUB: &getKeys(@_); -- REDUNDANT");
}

sub randKey {
    &DEBUG("STUB: &randKey(@_);");
}

##### $select is misleading???
# Usage: &searchTable($db, $returnkey, $primkey, $str);
sub searchTable {
    my ($db, $primkey, $key, $str) = @_;

    if (!scalar @{ "${db}_format" }) {
	&ERROR("sT: no valid format layout for $db.");
	return;
    }   

    my @results;
    foreach (keys %{$db}) {
	my $val = &dbGet($db, "NULL", $_, $key) || '';
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

1;
