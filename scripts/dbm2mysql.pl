#!/usr/bin/perl
# by the xk.
###

require "src/core.pl";
require "src/logger.pl";
require "src/modules.pl";

require "src/Misc.pl";
require "src/Files.pl";
&loadDBModules();
package MYSQL;
require "src/db_mysql.pl";
package DBM;
require "src/db_dbm.pl";
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

### open all the data...
&loadConfig("files/blootbot.config");
$dbname = $param{'DBName'};
my $dbh_mysql = MYSQL::openDB($param{'DBName'}, $param{'SQLUser'}, $param{'SQLPass'});
DBM::openDB();

print "scalar db == '". scalar(keys %db) ."'.\n";

my ($ndef, $i) = (1,1);
my $factoid;
foreach $factoid (keys %db) {
    foreach (@DBM::extra_format) {
	my $val = &DBM::getFactInfo($key, $_, $db{$key});
	if (!defined $val) {
	    $ndef++;
	    next;
	}
	&MYSQL::setFactInfo($key, $_, $val); # fact, type, what
    }
    $i++;
    print "i=$i... " if ($i % 100 == 0);
    print "ndef=$ndef... " if ($ndef % 1000 == 0);
}

print "Done.\n";
&closeDB();
