#
# insult.pl: insult engine
#      TODO: move this code out to a common file like I did with DNS.
#	     => use the command hooks system aswell
#

package Insult;

use strict;

sub Insult {
    my ($insultwho) = @_;
    return unless &::loadPerlModule("Net::Telnet");

    my $t = new Net::Telnet(Timeout => 3);
    $t->Net::Telnet::open(Host => "insulthost.colorado.edu", Port => "1695");
    my $line = $t->Net::Telnet::getline(Timeout => 4);

    $line = "No luck, $::who" unless (defined $line);

    if ($insultwho ne $::who) { 
	$line =~ s/^\s*You are/$insultwho is/i;
    }

    &::pSReply($line);
}

1;
