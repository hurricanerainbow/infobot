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
	$flag_quit $msgType
	$utime_userfile	$wtime_userfile	$ucount_userfile
	$utime_chanfile	$wtime_chanfile	$ucount_chanfile
);

# dynamic hash.
use vars qw(@joinchan @ircServers @wingateBad @wingateNow @wingateCache
);

### dynamic hash. MUST BE REDUCED IN SIZE!!!
# 
use vars qw(%count %netsplit %netsplitservers %flood %dcc %orig
	    %nuh %talkWho %seen %floodwarn %param %dbh %ircPort
	    %topic %moduleAge %last %time %mask %file
	    %forked %chanconf %channels
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
$utime_userfile	= 0;
$wtime_userfile	= 0;
$ucount_userfile = 0;
$utime_chanfile	= 0;
$wtime_chanfile	= 0;
$ucount_chanfile = 0;

$bot_version	= "blootbot cvs (20010214) -- $^O";
$noreply	= "NOREPLY";

##########
### misc commands.
###

sub doExit {
    my ($sig)	= @_;

    if (defined $flag_quit) {
	&WARN("doExit: quit already called.");
	return;
    }
    $flag_quit	= 1;

    if (!defined $bot_pid) {	# independent.
	exit 0;
    } elsif ($bot_pid == $$) {	# parent.
	&status("parent caught SIG$sig (pid $$).") if (defined $sig);

	&status("--- Start of quit.");

	&closeDCC();
	&closePID();
	&seenFlush();
	&quit($param{'quitMsg'}) if (&whatInterface() =~ /IRC/);
	&writeUserFile();
	&writeChanFile();
	&uptimeWriteFile()	if (&ChanConfList("uptime"));
	&closeDB();
	&closeSHM($shm);
	&dumpallvars()		if (&IsParam("dumpvarsAtExit"));
	&closeLog();
	&closeSQLDebug()	if (&IsParam("SQLDebug"));

	&status("--- QUIT.");
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

    $SIG{__WARN__} = 'doWarn';	# ???
}

# Usage: &IsParam($param);
# blootbot.config specific.
sub IsParam {
    my $param = $_[0];

    return 0 unless (defined $param);
    return 0 unless (exists $param{$param});
    return 0 unless ($param{$param});
    return 0 if $param{$param} =~ /^false$/i;
    return 1;
}

#####
#  Usage: &ChanConfList($param)
#  About: gets channels with 'param' enabled. (!!!)
# Return: array of channels
sub ChanConfList {
    my $param	= $_[0];
    return unless (defined $param);
    my %chan	= &getChanConfList($param);

    # what if we have it set on _default and a few channels with
    # negative set? perhaps we should disable -blah settings to remove
    # this mess.

    if (exists $chan{_default}) {
	return keys %chanconf;
    } else {
	### TODO: -option is included aswell though.
	return keys %chan;
    }
}

#####
#  Usage: &getChanConfList($param)
#  About: gets channels with 'param' enabled, internal use only.
# Return: hash of channels
sub getChanConfList {
    my $param	= $_[0];
    my %chan;

    return unless (defined $param);

    foreach (keys %chanconf) {
	my $chan	= $_;
#	&DEBUG("chan => $chan");
	my @array	= grep /^$param$/, keys %{ $chanconf{$chan} };

	next unless (scalar @array);

	if (scalar @array > 1) {
	    &WARN("multiple items found?");
	}

	if ($array[0] eq "0") {
	    $chan{$chan}	= -1;
	} else {
	    $chan{$chan}	=  1;
	}
    }

    return %chan;
}

#####
#  Usage: &IsChanConf($param);
#  About: Check for 'param' on the basis of channel config.
# Return: 1 for enabled, 0 for passive disable, -1 for active disable.
sub IsChanConf {
    my($param)	= shift;

    if (!defined $param) {
	&WARN("param == NULL.");
	return 0;
    }

    ### TODO: VERBOSITY on how chanconf returned 1 or 0 or -1.
    my %chan	= &getChanConfList($param);
    if (!defined $msgType) {
	return $chan{_default} || 0;
    }

    if ($msgType eq "public") {
	return $chan{lc $chan} || $chan{_default} || 0;
    }

    if ($msgType eq "private") {
	return $chan{_default} || 0;
    }

### debug purposes only.
#    &DEBUG("param => $param, msgType => $msgType.");
#    foreach (keys %chan) {
#	&DEBUG("   $_ => $chan{$_}");
#    }

    return 0;
}

#####
#  Usage: &getChanConf($param);
#  About: Retrieve value for 'param' value in current/default chan.
# Return: scalar for success, undef for failure.
sub getChanConf {
    my($param,$chan)	= @_;

    if (!defined $param) {
	&WARN("param == NULL.");
	return 0;
    }

    $chan	||= "_default";
    my @c	= grep /^$chan$/i, keys %chanconf;

    if (@c and $c[0] ne $chan) {
	&WARN("c ne chan ($c[0] ne $chan)");
    }

    return $chanconf{$c[0] || "_default"}{$param};
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

    } elsif ($^O eq "netbsd") {
	$memusage = (stat "/proc/$$/mem")[7]/1024;

    } elsif ($^O =~ /^(free|open)bsd$/) {
	my @info  = split /\s+/, `/bin/ps -l -p $$`;
	$memusage = $info[20];

    } else {
	$memusage = "UNKNOWN";
	return;
    }

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
    }
    $memusageOld = $memusage;
}

######
###### SETUP
######

sub setup {
    &showProc(" (\&openLog before)");
    &openLog();		# write, append.
    &status("--- Started logging.");

    foreach ("debian") {
	my $dir = "$bot_base_dir/$_/";
	next if ( -d $dir);
	&status("Making dir $_");
	mkdir $dir, 0755;
    }

    # read.
    &loadLang($bot_misc_dir.		"/blootbot.lang");
    &loadIRCServers();
    &readUserFile();
    &readChanFile();
    &loadMyModulesNow();	# must be after chan file.

    $shm = &openSHM();
    &openSQLDebug()	if (&IsParam("SQLDebug"));
    &openDB($param{'DBName'}, $param{'SQLUser'}, $param{'SQLPass'});

    &status("Setup: ". &countKeys("factoids") ." factoids.");

    $param{tempDir} =~ s#\~/#$ENV{HOME}/#;

    &status("Initial memory usage: $memusage kB");
}

sub setupConfig {
    $param{'VERBOSITY'} = 1;
    &loadConfig($bot_misc_dir."/blootbot.config");

    foreach ("ircNick", "ircUser", "ircName", "DBType", "tempDir") {
	next if &IsParam($_);
	&ERROR("Parameter $_ has not been defined.");
	exit 1;
    }

    if ($param{tempDir} =~ s#\~/#$ENV{HOME}/#) {
	&VERB("Fixing up tempDir.",2);
    }

    if ($param{tempDir} =~ /~/) {
	&ERROR("parameter tempDir still contains tilde.");
	exit 1;
    }

    if (! -d $param{tempDir}) {
	&status("making $param{tempDir}...");
	system("mkdir $param{tempDir}");
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
    $count{'Moron'}	= 0;
}

sub shutdown {
    # reverse order of &setup().
    &DEBUG("shutdown called.");

    &closeDB();
    &closeSHM($shm);	# aswell. TODO: use this in &doExit?
    &closeLog();
}

sub restart {
    my ($sig) = @_;

    if ($$ == $bot_pid) {
	&status("--- $sig called.");

	### crappy bug in Net::IRC?
	if (!$conn->connected and time - $msgtime > 900) {
	    &status("reconnecting because of uncaught disconnect.");
##	    $irc->start;
	    $conn->connect();
	    return;
	}

	&DCCBroadcast("-HUP called.","m");
	&shutdown();
	&loadConfig($bot_misc_dir."/blootbot.config");
	&reloadAllModules() if (&IsParam("DEBUG"));
	&setup();

	&status("--- End of $sig.");
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
