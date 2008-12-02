# W3Search drastically altered back to GoogleSearch as Search::Google 
# was deprecated and requires a key that google no longer provides. 
# This new module uses REST::Google::Search 
# Modified by db <db@cave.za.net> 12-01-2008. 
 
package Google;

use strict;

my $maxshow = 5;

sub GoogleSearch {
    my ( $what, $type ) = @_;
    my $where  = "Google";
    my $retval = "$where can't find \002$what\002";
    my $Search;

    return unless &::loadPerlModule("REST::Google::Search");

    REST::Google::Search->http_referer('http://infobot.sourceforge.net/');
    $Search = REST::Google::Search->new( q => $what );

    if ( !defined $Search ) {
        &::msg( $::who, "$where is invalid search." );
        return;
    }

    if ( $Search->responseStatus != 200 ) {
        &::msg( $::who, "http error returned." );
        return;
    }

    my $data    = $Search->responseData;
    my $cursor  = $data->cursor;
    my @results = $data->results;

    my $count;
    $retval = "$where says \002$what\002 is at ";
    foreach my $r (@results) {
        my $url = $r->url;
        $retval .= ' or ' if ( $count > 0 );
        $retval .= $url;
        last if ++$count >= $maxshow;
    }

    &::performStrictReply($retval);
}

1;
 
# vim:ts=4:sw=4:expandtab:tw=80 
