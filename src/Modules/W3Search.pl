# WWWSearch backend, with queries updating the is-db (optionally)
# Uses WWW::Search::Google and WWW::Search
# originally Google.pl, drastically altered.

package W3Search;

use strict;
use vars qw(@W3Search_engines $W3Search_regex);
@W3Search_engines = qw(AltaVista Dejanews Excite Gopher HotBot Infoseek
		Lycos Magellan PLweb SFgate Simple Verity Google);
$W3Search_regex = join '|', @W3Search_engines;

my $maxshow	= 3;

sub W3Search {
    my ($where, $what, $type) = @_;
    my $retval = "$where can't find \002$what\002";

    my @matches = grep { lc($_) eq lc($where) ? $_ : undef } @W3Search_engines;
    if (@matches) {
	$where = shift @matches;
    } else {
	&::msg($::who, "i don't know how to check '$where'");
	return;
    }

    return unless &::loadPerlModule("WWW::Search");

    my $Search	= new WWW::Search($where);
    my $Query	= WWW::Search::escape_query($what);
    $Search->native_query($Query,
#	{
#		search_debug => 2,
#		search_parse_debug => 2,
#	}
    );
    $Search->http_proxy($::param{'httpProxy'}) if (&::IsParam("httpProxy"));
    my $max = $Search->maximum_to_retrieve(10);	# DOES NOT WORK.

    my (%results, $count, $r);
    while ($r = $Search->next_result()) {
	my $url = $r->url();

	### TODO: fix regex.
	### TODO: use array to preserve order.
	if ($url =~ /^http:\/\/([\w\.]*)/) {
	    my $hostname = $1;
	    next if (exists $results{$hostname});
	    $results{$hostname} = $url;
	} else {
	    &::DEBUG("W3S: url isn't good? ($url).");
	}

	last if ++$count >= $maxshow;
    }

    if (scalar keys %results) {
	$retval = "$where says \002$what\002 is at ".
		join(' or ', map { $results{$_} } sort keys %results);
    }

    &::performStrictReply($retval);
}

1;
