# WWWSearch backend, with queries updating the is-db (optionally)
# Uses WWW::Search::Google and WWW::Search
# originally Google.pl, drastically altered.

package W3Search;

use strict;

my $maxshow	= 3;

sub W3Search {
    my ($where, $what, $type) = @_;
    my $retval = "$where can't find \002$what\002";

    return unless &main::loadPerlModule("WWW::Search");

    my @matches = grep { lc($_) eq lc($where) ? $_ : undef } @main::W3Search_engines;
    if (@matches) {
	$where = shift @matches;
    } else {
	&main::msg($main::who, "i don't know how to check '$where'");
    }

    my $Search	= new WWW::Search($where);
    my $Query	= WWW::Search::escape_query($what);
    $Search->native_query($Query,
#	{
#		search_debug => 2,
#		search_parse_debug => 2,
#	}
    );
    $Search->http_proxy($main::param{'httpProxy'}) if (&main::IsParam("httpProxy"));
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
	    &main::DEBUG("W3S: url isn't good? ($url).");
	}

	last if ++$count >= $maxshow;
    }

    if (scalar keys %results) {
	$retval = "$where says \002$what\002 is at ".
		join(' or ', map { $results{$_} } sort keys %results);
    }

    &main::performStrictReply($retval);
}

1;
