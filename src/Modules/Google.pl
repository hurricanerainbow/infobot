# W3Search drastically altered back to GoogleSearch as Search::Google 
# was deprecated and requires a key that google no longer provides. 
# This new module uses REST::Google::Search 
# Modified by db <db@cave.za.net> 12-01-2008. 
 
package Google;

use strict;

my $maxshow = 5;

sub GoogleSearch {
    my ( $what, $type ) = @_;
    # $where set to official google colors ;)
    my $where  = "\00312G\0034o\0038o\00312g\0033l\0034e\003";
    my $retval = "$where can't find \002$what\002";
    my $Search;
    my $referer = "irc://$::server/$::chan/$::who";

    return unless &::loadPerlModule("REST::Google::Search");

    &::DEBUG( "Google::GoogleSearch->referer = $referer" );
    &::status( "Google::GoogleSearch> Searching Google for: $what");
    REST::Google::Search->http_referer( $referer );
    $Search = REST::Google::Search->new( q => $what );

    if ( !defined $Search ) {
        &::msg( $::who, "$where is invalid search." );
        &::WARN( "Google::GoogleSearch> $::who generated an invalid search: $where");
        return;
    }

    if ( $Search->responseStatus != 200 ) {
        &::msg( $::who, "http error returned." );
        &::WARN( "Google::GoogleSearch> http error returned: $Search->responseStatus");
        return;
    }

    # No results found
    if ( not $Search->responseData->results ) {
        &::DEBUG( "Google::GoogleSearch> $retval" );
        &::msg( $::who, $retval);
        &::msg( $::who, $Search->responseStatus );
        return;
    }

    my $data    = $Search->responseData;
    my $cursor  = $data->cursor;
    my @results = $data->results;
    my $count;

    $retval = "$where says \"\002$what\002\" is at ";
    foreach my $r (@results) {
        my $url = $r->url;
        $retval .= " \002or\002 " if ( $count > 0 );
        $retval .= $url;
        last if ++$count >= $maxshow;
    }

    &::performStrictReply($retval);
}

1;
 
# vim:ts=4:sw=4:expandtab:tw=80 
