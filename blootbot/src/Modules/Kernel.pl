#
# Kernel.pl: Frontend to linux.kernel.org.
#    Author: dms
#   Version: v0.3 (19990919).
#   Created: 19990729
#

package Kernel;

use IO::Socket;
use strict;

### TODO: change this to http instead of finger?
my $server	= "ftp.kernel.org";
my $port	=  79;
my $proto	= getprotobyname('tcp');

###local $SIG{ALRM} = sub { die "alarm\n" };

sub kernelGetInfo {
###    return unless &main::loadPerlModule("IO::Socket");

    my $socket    = new IO::Socket;

    socket($socket, PF_INET, SOCK_STREAM, $proto) or return "error: socket: $!";
    eval {
	alarm 15;
	connect($socket, sockaddr_in($port, inet_aton($server))) or return "error: connect: $!";
	alarm 0;
    };

    my @retval;

    if ($@ && $@ ne "alarm\n") {		# failed.
	return;
    }

    $socket->autoflush(1);	# required.

    print $socket "\n";
    while (<$socket>) {
	chop;

	s/\t//g;
	s/\s$//;
	s/\s+/ /g;

	next if ($_ eq "");

	push(@retval, $_);
    }
    close $socket;

    @retval;
}

sub Kernel {
    my @now = &kernelGetInfo();
    if (!scalar @now) {
	&main::msg($main::who, "failed.");
	return;
    }

    foreach (@now) {
	&main::msg($main::who, $_);
    }
}

sub kernelAnnounce {
    my $file = "$main::blootbot_base_dir/Temp/kernel.txt";
    my @now  = &kernelGetInfo();
    my @old;

    if (!scalar @now) {
	&main::DEBUG("kA: failure to retrieve.");
	return;
    }

    if (! -f $file) {
	open(OUT, ">$file");
	foreach (@now) {
	    print OUT "$_\n";
	}
	close OUT;

	return;
    } else {
	open(IN, $file);
	while (<IN>) {
	    chop;
	    push(@old,$_);
	}
	close IN;
    }

    my @new;
    for(my $i=0; $i<scalar(@old); $i++) {
	next if ($old[$i] eq $now[$i]);
	push(@new, $now[$i]);
    }

    if (scalar @now != scalar @old) {
	&main::DEBUG("kA: scalar mismatch; removing and exiting.");
	unlink $file;
	return;
    }

    if (!scalar @new) {
	&main::DEBUG("kA: no new kernels.");
	return;
    }

    my $chan;
    my @chans = split(/[\s\t]+/, lc $main::param{'kernelAnnounce'});
    @chans    = keys(%main::channels) unless (scalar @chans);
    foreach $chan (@chans) {
	next unless (&main::validChan($chan));

	&main::status("sending kernel update to $chan.");
	foreach (@new) {
            &main::notice($chan, "Kernel: $_");
	}
    }

    open(OUT, ">$file");
    foreach (@now) {
	print OUT "$_\n";
    }
    close OUT;
}

1;
