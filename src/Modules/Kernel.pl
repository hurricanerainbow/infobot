#
# Kernel.pl: Frontend to linux.kernel.org.
#    Author: dms
#   Version: v0.3 (19990919).
#   Created: 19990729
#

package Kernel;

sub kernelGetInfo {
    return &::getURL("http://www.kernel.org/kdist/finger_banner");
}

sub Kernel {
    my @now = &kernelGetInfo();
    if (!scalar @now) {
	&::msg($::who, "failed.");
	return;
    }

    foreach (@now) {
	&::msg($::who, $_);
    }
}

sub kernelAnnounce {
    my $file = "$::param{tempDir}/kernel.txt";
    my @now  = &kernelGetInfo();
    my @old;

    if (!scalar @now) {
	&::DEBUG("kA: failure to retrieve.");
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
	&::DEBUG("kA: scalar mismatch; removing and exiting.");
	unlink $file;
	return;
    }

    if (!scalar @new) {
	&::DEBUG("kA: no new kernels.");
	return;
    }

    open(OUT, ">$file");
    foreach (@now) {
	print OUT "$_\n";
    }
    close OUT;

    return @new;
}

1;
