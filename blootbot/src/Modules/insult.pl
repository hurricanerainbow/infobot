#
# insult.pl: insult engine
#       ???: ???
#

use strict;

package Insult;

sub Insult {
    my ($insultwho) = @_;
    return unless &loadPerlModule("Net::Telnet");

    my $t = new Net::Telnet(Timeout => 3);
    $t->Net::Telnet::open(Host => "insulthost.colorado.edu", Port => "1695");
    my $line = $t->Net::Telnet::getline(Timeout => 4);

    $line = "No luck, $::who" unless (defined $line);

    if ($insultwho ne $::who) { 
	$line =~ s/^\s*You are/$insultwho is/i;
    }

    &performStrictReply($line);
}

1;
