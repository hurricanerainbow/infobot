#!/usr/bin/perl -w

$| = 1;

use strict;
use vars qw($bot_base_dir $bot_src_dir $bot_misc_dir $bot_state_dir
  $bot_data_dir $bot_config_dir $bot_log_dir $bot_run_dir
    $bot_pid $memusage %param
);


# Check for arguments
if ( !scalar @ARGV ) {
    print "Usage: $0 <pack1.fact> [<pack2.fact> <pack2.fact> ...]\n";
    print "Example: $0 areacodes.fact usazips.fact\n";
    exit 1;
}


# set any $bot_*_dir var's
$bot_base_dir   = '.';
$bot_config_dir = 'files/';
$bot_data_dir   = 'files/';
$bot_state_dir  = 'files/';
$bot_run_dir    = '.';
$bot_src_dir    = "$bot_base_dir/src";
$bot_log_dir    = "$bot_base_dir/log";
$bot_misc_dir   = "$bot_base_dir/files";
$bot_pid        = $$;

require "$bot_src_dir/logger.pl";
require "$bot_src_dir/core.pl";
require "$bot_src_dir/modules.pl";

# Initialize enough to get DB access
&setupConfig();
&loadCoreModules();
&loadDBModules();
&loadFactoidsModules();
&setup();

if ( !scalar @ARGV ) {
    print "Usage: $0 <pack1.fact> [<pack2.fact> <pack2.fact> ...]\n";
    print "Example: $0 areacodes.fact usazips.fact\n";
    exit 0;
}

foreach (@ARGV) {
    next unless ( -f $_ );
    my $file = $_;

    open( IN, $file ) or die "error: cannot open $file\n";
    print "Opened $file for input...\n";

    print "inserting... ";
    while (<IN>) {
        chomp;
        next if /^#/;
        next unless (/=>/);

        # Split into "key => value" pairs
        my ($key, $value) = split(/=>/,$_,2);

        # Strip extra begin/end whitespace
        $key =~ s/^\s*(.*?)\s*$/$1/;
        $value =~ s/^\s*(.*?)\s*$/$1/;
        
        # convert tabs
        $key =~ s/\t/ /g;
        $value =~ s/\t/ /g;

        # The key needs to be lower case to match query case
        $key = lc $key;

        ### TODO: check if it already exists. if so, don't add.
        ### TODO: combine 2 setFactInfo's into single
        &setFactInfo( $key, "factoid_value", $value );
        &setFactInfo( $key, "created_by", $file );
        print ":: $key ";
    }

    close IN;
}
print "...Done!\n";

# vim:ts=4:sw=4:expandtab:tw=80
