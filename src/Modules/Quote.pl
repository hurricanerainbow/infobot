#
#  Quote.pl: retrieve stock quotes from yahoo
#            heavily based on Slashdot.pl
#   Version: v0.1
#    Author: Michael Urman <mu@zen.dhis.org>
# Licensing: Artistic
#

package Quote;

use strict;

sub Quote {
    my $stock = shift;
    my @results = &::getURL("http://quote.yahoo.com/q?s=$stock&d=v1");

    if (!scalar @results) {
	&::msg($::who, "i could not get a stock quote :(");
    }

    my $flathtml = join(" ", @results);

    local ($/) = "\n\n";
    for ($flathtml) {
	s/.*?\<tr align=right\>//;
	s/Chart.*//;
	s/<.*?>//g;		# remove HTML stuff.
	s/\s{2,}/ /g;		# reduce excessive spaces.
	s/^\s+//;		# get rid of leading whitespace
	s/\s+$//;		# get rid of trailing whitespace
    }
    my $reply = $flathtml;

    if ($reply eq "" or length($reply) > 160) {
	$reply = "i couldn't get the quote for $stock. sorry. :(";
    }

    &::performStrictReply($reply);
}

1;
