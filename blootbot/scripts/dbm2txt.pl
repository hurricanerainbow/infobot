#!/usr/bin/perl -w

use strict;

if (!scalar @ARGV) {
    print "Usage: dbm2txt <whatever dbm>\n";
    print "Example: dbm2txt.pl factoids\n";
    exit 0;
}

my $dbfile = shift;
my %db;
if (0) {
    require "src/Factoids/db_dbm.pl";
    openDB();
}

dbmopen(%db,$dbname,0444) or die "error: cannot open db.\n";
foreach (keys %db) {
  next if /=>/;		# skip the key if it contains the delimiter.

  print "$_ => $db{$_}\n";
}
dbmclose %db;
