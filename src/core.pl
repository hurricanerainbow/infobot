#
#   core.pl: Important functions stuff...
#    Author: dms
#   Version: v0.4 (20000718)
#   Created: 20000322
#

use strict;

# dynamic scalar. MUST BE REDUCED IN SIZE!!!
### TODO: reorder.
use vars qw(
	$answer $correction_plausible $talkchannel
	$statcount $memusage $user $memusageOld $bot_version $dbh
	$shm $host $msg $bot_misc_dir $bot_pid $bot_base_dir $noreply
	$bot_src_dir $conn $irc $learnok $nick $ident $no_syscall
	$force_public_reply $addrchar $userHandle $addressedother
	$floodwho $chan $msgtime $server $firsttime $wingaterun
);

# dynamic hash.
use vars qw(@joinchan @ircServers @wingateBad @wingateNow @wingateCache
);

# dynamic hash. MUST BE REDUCED IN SIZE!!!
use vars qw(%count %netsplit %netsplitservers %flood %dcc %orig
	    %nuh %talkWho %seen %floodwarn %param %dbh %ircPort %userList
	    %jointime %topic %joinverb %moduleAge %last %time %mask %file
);

# Signals.
$SIG{'HUP'}  = 'restart'; #  1.
$SIG{'INT'}  = 'doExit';  #  2.
$SIG{'KILL'} = 'doExit';  #  9. DOES NOT WORK. 'man perlipc' for details.
$SIG{'TERM'} = 'doExit';  # 15.
$SIG{'__WARN__'} = 'doWarn';

# initialize variables.
$last{buflen}	= 0;
$last{say}	= "";
$last{msg}	= "";
$userHandle	= "default";
$msgtime	= time();
$wingaterun	= time();
$firsttime	= 1;

### CHANGE TO STATIC.
$bot_version = "blootbot 1.0.0 (20000725) -- $^O";
$noreply	 = "NOREPLY";

##########
### misc commands.
###

sub doExit {
    my ($sig) = @_;

    if (!defined $bot_pid) {	# independent.
	exit 0;
    } elsif ($bot_pid == $$) {	# parent.
	&status("parent caught SIG$sig (pid $$).") if (defined $sig);

	my $type;
	&closeDCC();
	&closePID();
	&seenFlush();
	&quit($param{'quitMsg'}) if (&whatInterface() =~ /IRC/);
	&uptimeWriteFile();
	&closeDB();
	&closeSHM($shm);
	&dumpallvars()  if (&IsParam("dumpvarsAtExit"));
	&closeLog();
	&closeSQLDebug()	if (&IsParam("SQLDebug"));
    } else {					# child.
	&status("child caught SIG$sig (pid $$).");
    }

    exit 0;
}

sub doWarn {
    $SIG{__WARN__} = sub { warn $_[0]; };

    foreach (@_) {
	&WARN("PERL: $_");
    }

    $SIG{__WARN__} = 'doWarn';
}

# Usage: &IsParam($param);
sub IsParam {
    my $param = $_[0];

    return 0 unless (defined $param);
    return 0 unless (exists $param{$param});
    return 0 unless ($param{$param});
    return 0 if $param{$param} =~ /^false$/i;
    return 1;
}

sub showProc {
    my ($prefix) = $_[0] || "";

    if (!open(IN, "/proc/$$/status")) {
	&ERROR("cannot open '/proc/$$/status'.");
	return;
    }

    if ($^O eq "linux") {
	while (<IN>) {
	    $memusage = $1 if (/^VmSize:\s+(\d+) kB/);
	}
	close IN;

	if (defined $memusageOld and &IsParam("DEBUG")) {
	    # it's always going to be increase.
	    my $delta = $memusage - $memusageOld;
	    my $str;
	    if ($delta == 0) {
		return;
	    } elsif ($delta > 500) {
		$str = "MEM:$prefix increased by $delta kB. (total: $memusage kB)";
	    } elsif ($delta > 0) {
		$str = "MEM:$prefix increased by $delta kB";
	    } else {	# delta < 0.
		$delta = -$delta;
		# never knew RSS could decrease, probably Size can't?
		$str = "MEM:$prefix decreased by $delta kB. YES YES YES";
	    }

	    &status($str);
	    &DCCBroadcast($str) if (&whatInterface() =~ /IRC/ &&
		grep(/Irc.pl/, keys %moduleAge));
	}
	$memusageOld = $memusage;
    } else {
	$memusage = "UNKNOWN";
    }
    ### TODO: FreeBSD/*BSD support.
}

######
###### SETUP
######

sub setup {
    &showProc(" (\&openLog before)");
    &openLog();		# write, append.

    foreach ("debian","Temp") {
	&status("Making dir $_");
	mkdir "$bot_base_dir/$_/", 0755;
    }

    # read.
    &loadIgnore($bot_misc_dir.		"/blootbot.ignore");
    &loadLang($bot_misc_dir.		"/blootbot.lang");
    &loadIRCServers($bot_misc_dir.	"/ircII.servers");
    &loadUsers($bot_misc_dir.		"/blootbot.users");

    $shm = &openSHM();
    &openSQLDebug()	if (&IsParam("SQLDebug"));
    &openDB($param{'DBName'}, $param{'SQLUser'}, $param{'SQLPass'});

    &status("Setup: ". &countKeys("factoids") ." factoids.");

    &status("Initial memory usage: $memusage kB");
}

sub setupConfig {
    $param{'VERBOSITY'} = 1;
    &loadConfig($bot_misc_dir."/blootbot.config");

    foreach ("ircNick", "ircUser", "ircName", "DBType") {
	next if &IsParam($_);
	&ERROR("Parameter $_ has not been defined.");
	exit 1;
    }

    # static scalar variables.
    $file{utm}	= "$bot_base_dir/$param{'ircUser'}.uptime";
    $file{PID}	= "$bot_base_dir/$param{'ircUser'}.pid";
}

sub startup {
    if (&IsParam("DEBUG")) {
	&status("enabling debug diagnostics.");
	### I thought disabling this reduced memory usage by 1000 kB.
	use diagnostics;
    }

    $count{'Question'}	= 0;
    $count{'Update'}	= 0;
    $count{'Dunno'}	= 0;

    &loadMyModulesNow();
}

sub shutdown {
    # reverse order of &setup().
    &closeDB();
    &closeSHM($shm);	# aswell. TODO: use this in &doExit?
    &closeLog();
}

sub restart {
    my ($sig) = @_;

    if ($$ == $bot_pid) {
	&status("$sig called.");

	### crappy bug in Net::IRC?
	if (!$conn->connected and time - $msgtime > 900) {
	    &status("reconnecting because of uncaught disconnect.");
##	    $irc->start;
	    $conn->connect();
	    return;
	}

	&shutdown();
	&loadConfig($bot_misc_dir."/blootbot.config");
	&reloadAllModules() if (&IsParam("DEBUG"));
	&setup();

	&status("End of $sig.");
    } else {
	&status("$sig called; ignoring restart.");
    }
}

# File: Configuration.
sub loadConfig {
    my ($file) = @_;

    if (!open(FILE, $file)) {
	&ERROR("FAILED loadConfig ($file): $!");
	&status("Please copy files/sample.config to files/blootbot.config");
	&status("  and edit files/blootbot.config, modify to tastes.");
	exit 0;
    }

    my $count = 0;
    while (<FILE>) {
	chomp;
	next if /^\s*\#/;
	next unless /\S/;
	my ($set,$key,$val) = split(/\s+/, $_, 3);

	if ($set ne "set") {
	    &status("loadConfig: invalid line '$_'.");
	    next;
	}

	# perform variable interpolation
	$val =~ s/(\$(\w+))/$param{$2}/g;

	$param{$key} = $val;

	++$count;
    }
    close FILE;

    $file =~ s/^.*\///;
    &status("Loaded config $file ($count items)");
}

1;
