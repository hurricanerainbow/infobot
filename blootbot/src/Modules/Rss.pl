#
#     Rss.pl: rss handler hacked from Plug.pl
#     Author: Tim Riker <Tim@Rikers.org>
#  Licensing: Artistic License (as perl itself)
#    Version: v0.1
#

package Rss;

use strict;

sub Rss::Titles {
	my @list;

	foreach (@_) {
		next unless (/<title>(.*?)<\/title>/);
		my $title = $1;
		$title =~ s/&amp\;/&/g;
		push(@list, $title);
	}

	return @list;
}

sub Rss::Rss {
	my ($message) = @_;
	my @results = &::getURL($message);
	my $retval  = "i could not get the rss feed.";

	if (scalar @results) {
		my $prefix	= "Titles: ";
		my @list	= &Rss::Titles(@results);
		$retval		= &::formListReply(0, $prefix, @list);
	}

	&::performStrictReply($retval);
}

1;
# vim: ts=2 sw=2
