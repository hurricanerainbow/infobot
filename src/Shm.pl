#
#   Shm.pl: Shared Memory stuff.
#    Author: dms
#   Version: 20000201
#   Created: 20000124
#

if (&IsParam("useStrict")) { use strict; }

use POSIX qw(_exit);

sub openSHM {
    my $IPC_PRIVATE = 0;
    my $size = 2000;

    if (defined( $_ = shmget($IPC_PRIVATE, $size, 0777) )) {
	&status("Created shared memory (shm) key: [$_]");
	return $_;
    } else {
	&ERROR("openSHM: failed.");
	&ERROR("Please delete some shared memory with ipcs or ipcrm.");
	exit 1;
    }
}

sub closeSHM {
    my ($key) = @_;
    my $IPC_RMID = 0;

    return '' if (!defined $key);

    &shmFlush();
    &status("Closed shared memory (shm) key: [$key]");
    return shmctl($key, $IPC_RMID, 0);
}

sub shmRead {
    my ($key) = @_;
    my $position = 0;
    my $size = 3*80;
    my $retval = '';

    if (shmread($key,$retval,$position,$size)) {
	return $retval;
    } else {
	&ERROR("shmRead: failed: $!");
	return '';
    }
}

sub shmWrite {
    my ($key, $str) = @_;
    my $position = 0;
    my $size = 80*3;

    # NULL hack.
    ### TODO: create shmClear to deal with this.
    if ($str !~ /^$/) {
	my $read = &shmRead($key);
	$read =~ s/\0+//g;
	$str = $read ."||". $str if ($read ne "");
    }

    if (!shmwrite($key,$str,$position,$size)) {
	&ERROR("shmWrite: failed: $!");
    }
}

##############
### Helpers
###

# Usage: &addForked($name);
# Return: 1 for success, 0 for failure.
sub addForked {
    my ($name)		= @_;
    my $forker_timeout	= 360;	# 6mins, in seconds.
    $forker		= $name;

    if (!defined $name) {
	&WARN("addForked: name == NULL.");
	return 0;
    }

    foreach (keys %forked) {
	my $time = time() - $forked{$_}{Time};
	next unless ($time > $forker_timeout);

	### TODO: use &time2string()?
	&WARN("Fork: looks like we lost '$_', executed $time ago.");
	delete $forked{$_};
    }

    my $count = 0;
    while (scalar keys %forked > 2) {	# 2 or more == fail.
	sleep 1;

	if ($count > 3) {	# 3 seconds.
	    my $list = join(', ', keys %forked);
	    if (defined $who) {
		&msg($who, "already running ($list) => exceeded allowed forked processes count (1?).");
	    } else {
		&status("Fork: I ran too many forked processes :) Giving up $name.");
	    }
	    return 0;
	}

	$count++;
    }

    if (exists $forked{$name}) {
	my $time	= $forked{$name}{Time};
	my $continue	= 0;

	if (-d "/proc/$forked{$name}{PID}") {
	    &status("fork: still running; good. BAIL OUT.");
	} else {
	    &WARN("Found dead fork; removing and resetting.");
	    $continue = 1;
	}

	if ($continue) {
	    # NOTHING.
	} elsif (time() - $time > 900) {	# stale fork > 15m.
	    &status("forked: forked{$name} presumably exited without notifying us.");
	} else {				# fresh fork.
	    &msg($who, "$name is already running ". &Time2String(time() - $time));
	    return 0;
	}
    }

    $forked{$name}{Time}	= time();
    $forkedtime			= time();
    $count{'Fork'}++;
    return 1;
}

sub delForked {
    my ($name)	= @_;

    return if ($$ == $bot_pid);

    if (!defined $name) {
	&WARN("delForked: name == NULL.");
	POSIX::_exit(0);
    }

    &showProc();	# just for informational purposes.

    if (exists $forked{$name}) {
	my $timestr = &Time2String(time() - $forked{$name}{Time});
	&status("fork: took $timestr for $name.");
	&shmWrite($shm,"DELETE FORK $name");
    } else {
	&ERROR("delForked: forked{$name} does not exist. should not happen.");
    }

    &status("--- fork finished for '$name' ---");

    POSIX::_exit(0);
}

1;
