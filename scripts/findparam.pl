#!/usr/bin/perl -w

use strict;

my(%param, %conf, %both);

foreach (`find -name "*.pl"`) {
    chop;
    my $file = $_;

    open(IN, $file);
    while (<IN>) {
	chop;

	if (/IsParam\(['"](\S+?)['"]\)/) {
#	    print "File: $file: IsParam: $1\n";
	    $param{$1}++;
	    next;
	}

	if (/hasParam\(['"](\S+?)['"]\)/) {
#	    print "File: $file: hasParam: $1\n";
	    $param{$1}++;
	    next;
	}

	if (/getChanConfDefault\(['"](\S+?)['"]/) {
#	    print "File: $file: gCCD: $1\n";
	    $both{$1}++;
	    next;
	}

	if (/getChanConf\(['"](\S+?)['"]\)/) {
#	    print "File: $file: gCC: $1\n";
	    $conf{$1}++;
	    next;
	}

	if (/IsChanConf\(['"](\S+?)['"]\)/) {
#	    print "File: $file: ICC: $1\n";
	    $conf{$1}++;
	    next;
	}
    }
    close IN;
}

print "Conf AND/OR Params:\n";
foreach (sort keys %both) {
    print "    $_\n";
}
print "\n";

print "Params:\n";
foreach (sort keys %param) {
    print "    $_\n";
}
print "\n";

print "Conf:\n";
foreach (sort keys %conf) {
    print "    $_\n";
}
