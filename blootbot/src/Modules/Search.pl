#
# infobot copyright kevin lenzo 1997-1998
# rewritten by xk 1999
#

package Search;

use strict;

###
# Search(keys||vals, str);
sub Search {
    my ($type, $str) = @_;
    my $start_time = &main::gettimeofday();
    my @list;

    $type =~ s/s$//;	# nice work-around.

    if ($type eq "value") {	# search by value.
	@list = &main::searchTable("factoids", "factoid_key", "factoid_value", $str);
    } else {			# search by key.
	@list = &main::searchTable("factoids", "factoid_key", "factoid_key", $str);
    }

    my $delta_time = sprintf("%.02f", &main::gettimeofday() - $start_time);
    &main::status("search: took $delta_time sec for query.") if ($delta_time > 0);

    my $prefix = "Factoid search of '\002$str\002' by $type ";

    &main::performStrictReply( &main::formListReply(1, $prefix, @list) );
}

1;
