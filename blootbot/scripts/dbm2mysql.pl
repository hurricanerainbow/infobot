#!/usr/bin/perl
# by the xk.
###

require "src/core.pl";
require "src/logger.pl";
require "src/modules.pl";

require "src/Misc.pl";
require "src/Files.pl";
&loadDBModules();
require "src/dbi.pl";
package main;

if (!scalar @ARGV) {
    print "Usage: dbm2mysql <whatever dbm>\n";
    print "Example: dbm2mysql.pl apt\n";
    print "NOTE: suffix '-is' and '-extra' are used.\n";
    exit 0;
}

my $dbfile = shift;
my $key;
my %db;

# open dbm.
if (dbmopen(%{ $dbm }, $dbfile, 0666)) {
    &status("::: opening dbm file: $dbfile");
} else {
    &ERROR("Failed open to dbm file ($dbfile).");
    exit 1;
}

### open all the data...
&loadConfig("files/blootbot.config");
$dbname = $param{'DBName'};
my $dbh_mysql = sqlOpenDB($param{'DBName'},
	$param{'DBType'}, $param{'SQLUser'}, $param{'SQLPass'});

print "scalar db == '". scalar(keys %db) ."'.\n";

my ($ndef, $i) = (1,1);
my $factoid;
foreach $factoid (keys %db) {
    # blootbot dbm to sql support:
    if (0) {
	foreach (@DBM::extra_format) {
#	    my $val = &getFactInfo($key, $_, $db{$key});
	    if (!defined $val) {
		$ndef++;
		next;
	    }
	}
    } else {
	# infobot dbm to blootbot sql support.
	&sqlReplace("factoids", {
		factoid_key	=> $_,
		factoid_value	=> $db{$_},
	} );
    }

    $i++;
    print "i=$i... " if ($i % 100 == 0);
    print "ndef=$ndef... " if ($ndef % 1000 == 0);
}

print "Done.\n";
&closeDB();
dbmclose(%{ $dbm });
