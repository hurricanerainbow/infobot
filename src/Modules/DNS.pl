
# infobot :: Kevin Lenzo  (c) 1997

# once again, thanks to Patrick Cole

#use POSIX;
use Socket;
use strict;

use vars qw($waitedpid);

sub REAPER {
	$SIG{CHLD} = \&REAPER;	# loathe sysV
	$waitedpid = wait;
}

$SIG{CHLD} = \&REAPER;

sub DNS {
    my $in = $_[0];
    my($match, $x, $y, $result);
    my $pid;

    if (!defined($pid = fork)) {
	return "no luck, $who";
    } elsif ($pid) {
	# parent
    } else {
	# child
	if ($in =~ /(\d+\.\d+\.\d+\.\d+)/) {
	    &status("DNS query by IP address: $in");
	    $match = $1;
	    $y = pack('C4', split(/\./, $match));
	    $x = (gethostbyaddr($y, &AF_INET));
	    if ($x !~ /^\s*$/) {
		$result = $match." is ".$x unless ($x =~ /^\s*$/);
	    } else {
		$result = "I can't seem to find that address in DNS";
	    }
	} else {
	    &status("DNS query by name: $in");
	    $x = join('.',unpack('C4',(gethostbyname($in))[4]));
	    if ($x !~ /^\s*$/) {
		$result = $in." is ".$x;
	    } else {
		$result = "I can\'t find that machine name";
	    }
	}

	if ($msgType eq 'public') {
	    &say($result);
	} else {
	    &msg($who, $result);
	}
	exit;			# bye child
    }
}

1;
