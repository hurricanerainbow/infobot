#
#  Weather.pl: Frontend to GEO::Weather (weather.com).
#      Author: logeist
#     Version: v0.1 (20020512).
#     Created: 20020512.
#

package Weather;

use IO::Socket;
use strict;

###local $SIG{ALRM} = sub { die "alarm\n" };

sub Weather {
    my ($query) = @_;
    my (@weatherloc, $whash); 
    my $retval;

    return unless &::loadPerlModule("Geo::Weather");
    my $weather = new Geo::Weather;

    for ($query) {
	s/^[\s\t]+//;
	s/[\s\t]+$//;
	s/[\s\t]+/ /;
    }

    @weatherloc = split /,\s*/, $query;

    if (@weatherloc == 1) { 
        $whash = $weather->get_weather ("$weatherloc[0]");
    } else {
	$whash = $weather->get_weather ("$weatherloc[0]", "$weatherloc[1]");
    }

    if (!ref $whash) {
	$retval = "I'm sorry, not able to return weather conditions for $query";
	&::performStrictReply($retval);
	undef $weather;
	return;
    }

    $retval = "Current conditions in $whash->{city}, $whash->{state}: $whash->{cond}, $whash->{temp}° F.  Winds $whash->{wind} MPH.  Dewpoint: $whash->{dewp}° F, Relative Humidity: $whash->{humi}%,";

    if ($whash->{visb} eq 'Unlimited') {
	$retval .= " Visibility: $whash->{visb}, ";
    } else {
	$retval .= " Visibility: $whash->{visb} mi., ";
    }

    $retval .= " Barometric Pressure: $whash->{baro} in.";
    if($whash->{heat} ne 'N/A') {
	$retval .= " Heat Index: $whash->{heat}° F.";
    }

    &::performStrictReply($retval);
    undef $weather;
}

1;
