#
# ProcessExtra.pl: Extensions to Process.pl
#          Author: dms
#         Version: v0.5 (20010124)
#         Created: 20000117
#

if (&IsParam("useStrict")) { use strict; }

use POSIX qw(strftime);
use vars qw(%sched);

#
# is there a point in ScheduleChecked()?
# not yet... not unless we run setupSchedulers more than once.
#

sub setupSchedulers {
    &VERB("Starting schedulers...",2);

    # ONCE OFF.

    # REPETITIVE.
    &uptimeCycle(1);
    &randomQuote(2);
    &randomFactoid(2);
    &randomFreshmeat(2);
    &logCycle(1);
    &chanlimitCheck(1);
    &netsplitCheck(1);	# mandatory
    &floodCycle(1);	# mandatory
    &seenFlush(1);
    &leakCheck(1);	# mandatory
    &ignoreCheck(1);	# mandatory
    &seenFlushOld(1);
    &ircCheck(1);	# mandatory
    &miscCheck(1);	# mandatory
    &shmFlush(1);	# mandatory
    &slashdotCycle(2);
    &freshmeatCycle(2);
    &kernelCycle(2);
    &wingateWriteFile(1);
    &factoidCheck(1);

#    my $count = map { exists $sched{$_}{RUNNING} } keys %sched;
    my $count	= 0;
    foreach (keys %sched) {
	next unless (exists $sched{$_}{RUNNING});
	$count++;
    }

    &status("Schedulers: $count will be running.");
###    &scheduleList();
}

sub ScheduleThis {
    my ($interval, $codename, @args) = @_;
    my $waittime = &getRandomInt($interval);

    if (!defined $waittime) {
	&WARN("interval == waittime == UNDEF for $codename.");
	return;
    }

    if (exists $sched{$codename}) {
	&WARN("Sched for $codename already exists.");
	return;
    }

    &VERB("Scheduling \&$codename() for ".&Time2String($waittime),3);
    my $retval = $conn->schedule($waittime, \&$codename, @args);
    $sched{$codename}{LABEL}	= $retval;
    $sched{$codename}{TIME}	= time()+$waittime;
    $sched{$codename}{RUNNING}	= 1;
}

sub ScheduleChecked {
    my ($codename) = shift;

    # what the hell is this for?
    if (exists $sched{$codename}{RUNNING}) {
	&DEBUG("SC: Removed $codename.");
	delete $sched{$codename}{RUNNING};
    } else {
###	&WARN("sched $codename already removed.");
    }
}

####
#### LET THE FUN BEGIN.
####

sub randomQuote {
    my $interval = $param{'randomQuoteInterval'} || 60;
    &ScheduleThis($interval, "randomQuote") if (@_);
    &ScheduleChecked("randomQuote");
    return if ($_[0] eq "2");	# defer.

    my $line = &getRandomLineFromFile($bot_misc_dir. "/blootbot.randtext");
    if (!defined $line) {
	&ERROR("random Quote: weird error?");
	return;
    }

    foreach ( &ChanConfList("randomQuote") ) {
	next unless (&validChan($_));	# ???

	&status("sending random Quote to $_.");
	&action($_, "Ponders: ".$line);
    }
    ### TODO: if there were no channels, don't reschedule until channel
    ###		configuration is modified.
}

sub randomFactoid {
    my ($key,$val);
    my $error = 0;

    my $interval = $param{'randomFactoidInterval'} || 60; # FIXME.
    &ScheduleThis($interval, "randomFactoid") if (@_);
    &ScheduleChecked("randomFactoid");
    return if ($_[0] eq "2");	# defer.

    while (1) {
	($key,$val) = &randKey("factoids","factoid_key,factoid_value");
###	$val =~ tr/^[A-Z]/[a-z]/;	# blah is Good => blah is good.
	last if ($val !~ /^</);
	$error++;
	if ($error == 5) {
	    &ERROR("rF: tried 5 times but failed.");
	    return;
	}
    }

    foreach ( &ChanConfList("randomFactoid") ) {
	next unless (&validChan($_));	# ???

	&status("sending random Factoid to $_.");
	&action($_, "Thinks: \037$key\037 is $val");
	### FIXME: Use &getReply() on above to format factoid properly?
	$good++;
    }
}

sub randomFreshmeat {
    my $interval = $param{'randomFresheatInterval'} || 60;
    &ScheduleThis($interval, "randomFreshmeat") if (@_);
    &ScheduleChecked("randomFreshmeat");
    return if ($_[0] eq "2");	# defer.

    my @chans = &ChanConfList("randomFreshmeat");
    return unless (scalar @chans);

    &Forker("freshmeat", sub {
	my $retval = &Freshmeat::randPackage();

	foreach (@chans) {
	    next unless (&validChan($_));	# ???

	    &status("sending random Freshmeat to $_.");
	    &say($_, $line);
	}
    } );
}

sub logCycle {
    if (@_) {
	&ScheduleThis(60, "logCycle");
	&ScheduleChecked("logCycle");
	return if ($_[0] eq "2");	# defer.
    }

    return unless (defined fileno LOG);
    return unless (&IsParam("logfile"));
    return unless (&IsParam("maxLogSize"));

    ### check if current size is too large.
    if ( -s $file{log} > $param{'maxLogSize'}) {
	my $date = sprintf("%04d%02d%02d", (localtime)[5,4,3]);
	$file{log} = $param{'logfile'} ."-". $date;
	&status("cycling log file.");

	if ( -e $file{log}) {
	    my $i = 1;
	    my $newlog;
	    while () {
		$newlog = $file{log}."-".$i;
		last if (! -e $newlog);
		$i++;
	    }
	    $file{log} = $newlog;
	}

	&closeLog();
	system("/bin/mv '$param{'logfile'}' '$file{log}'");
	&compress($file{log});
	&openLog();
	&status("cycling log file.");
    }

    ### check if all the logs exceed size.
    my $logdir = "$bot_base_dir/log/";
    if (opendir(LOGS, $logdir)) {
	my $tsize = 0;
	my (%age, %size);

	while (defined($_ = readdir LOGS)) {
	    my $logfile		= "$logdir/$_";

	    next unless ( -f $logfile);
	    my $size		= -s $logfile;
	    my $age		= (stat $logfile)[9];

	    $age{$age}		= $logfile;
	    $size{$logfile}	= $size;

	    $tsize		+= $size;
	}
	closedir LOGS;

	my $delete	= 0;
	while ($tsize > $param{'maxLogSize'}) {
	    &status("LOG: current size > max ($tsize > $param{'maxLogSize'})");
	    my $oldest	= (sort {$a <=> $b} keys %age)[0];
	    &status("LOG: unlinking $age{$oldest}.");
	    unlink $age{$oldest};
	    $tsize	-= $oldest;
	    $delete++;
	}

	### TODO: add how many b,kb,mb removed?
	&status("LOG: removed $delete logs.") if ($delete);
    } else {
	&WARN("could not open dir $logdir");
    }

}

sub seenFlushOld {
    if (@_) {
	&ScheduleThis(1440, "seenFlushOld");
	&ScheduleChecked("seenFlushOld");
	return if ($_[0] eq "2");	# defer.
    }

    # is this global-only?
    return unless (&IsChanConf("seen") > 0);
    return unless (&IsChanConf("seenFlushInterval") > 0);

    my $max_time = ($chanconf{_default}{'seenMaxDays'} || 30)
				*60*60*24; # global.
    my $delete   = 0;

    if ($param{'DBType'} =~ /^pg|postgres|mysql/i) {
	my $query = "SELECT nick,time FROM seen GROUP BY nick HAVING UNIX_TIMESTAMP() - time > $max_time";
	my $sth = $dbh->prepare($query);
	$sth->execute;

	while (my @row = $sth->fetchrow_array) {
	    my ($nick,$time) = @row;

	    &dbDel("seen","nick",$nick);
	    $delete++;
	}
	$sth->finish;
    } elsif ($param{'DBType'} =~ /^dbm/i) {
	my $time = time();

	foreach (keys %seen) {
	    my $delta_time = $time - &dbGet("seen", "NULL", $_, "time");
	    next unless ($delta_time > $max_time);

	    &DEBUG("seenFlushOld: ".&Time2String($delta_time) );
	    delete $seen{$_};
	    $delete++;
	}
    } else {
	&FIXME("seenFlushOld: for PG/NO-DB.");
    }
    &VERB("SEEN deleted $delete seen entries.",2);

}

sub chanlimitCheck {
    if (@_) {
	my $interval = &getChanConf("chanlimitcheckInterval") || 10;
	&ScheduleThis($interval, "chanlimitCheck");
	&ScheduleChecked("chanlimitCheck");
	return if ($_[0] eq "2");
    }

    foreach ( &ChanConfList("chanlimitcheck") ) {
	next unless (&validChan($_));	# ???

	my $limitplus	= &getChanConf("chanlimitcheckPlus",$_) || 5;
	my $newlimit	= scalar(keys %{$channels{$_}{''}}) + $limitplus;
	my $limit	= $channels{$_}{'l'};

	if (scalar keys %{$channels{$_}{''}} > $limit) {
	    &status("LIMIT: set too low!!! FIXME");
	    ### run NAMES again and flush it.
	}

	next unless (!defined $limit or $limit != $newlimit);

	if (!exists $channels{$_}{'o'}{$ident}) {
	    &ERROR("chanlimitcheck: dont have ops on $_.");
	    next;
	}
	&rawout("MODE $_ +l $newlimit");
    }

}

sub netsplitCheck {
    my ($s1,$s2);

    if (@_) {
	&ScheduleThis(30, "netsplitCheck");
	&ScheduleChecked("netsplitCheck");
	return if ($_[0] eq "2");
    }

    foreach $s1 (keys %netsplitservers) {
	foreach $s2 (keys %{$netsplitservers{$s1}}) {
	    if (time() - $netsplitservers{$s1}{$s2} > 3600) {
		&status("netsplit between $s1 and $s2 appears to be stale.");
		delete $netsplitservers{$s1}{$s2};
	    }
	}
    }

    # %netsplit hash checker.
    foreach (keys %netsplit) {
	if (&IsNickInAnyChan($_)) {
	    &DEBUG("netsplitC: $_ is in some chan; removing from netsplit list.");
	    delete $netsplit{$_};
	}
	next unless (time() - $netsplit{$_} > 60*60*2); # 2 hours.
	next if (&IsNickInAnyChan($_));

	&DEBUG("netsplitC: $_ didn't come back from netsplit in 2 hours; removing from netsplit list.");
	delete $netsplit{$_};
    }
}

sub floodCycle {
    my $delete   = 0;
    my $who;

    if (@_) {
	&ScheduleThis(60, "floodCycle");	# minutes.
	&ScheduleChecked("floodCycle");
	return if ($_[0] eq "2");
    }

    my $time	= time();
    foreach $who (keys %flood) {
	foreach (keys %{$flood{$who}}) {
	    if (!exists $flood{$who}{$_} or defined $flood{$who}{$_}) {
		&WARN("flood{$who}{$_} undefined?");
		next;
	    }

	    if ($time - $flood{$who}{$_} > $interval) {
		delete $flood{$who}{$_};
		$delete++;
	    }
	}
    }
    &VERB("floodCycle: deleted $delete items.",2);

}

sub seenFlush {
    my %stats;
    my $nick;
    my $flushed 	= 0;
    $stats{'count_old'} = &countKeys("seen");
    $stats{'new'}	= 0;
    $stats{'old'}	= 0;

    if (@_) {
	my $interval = $param{'seenFlushInterval'} || 60;
	&ScheduleThis($interval, "seenFlush");
	&ScheduleChecked("seenFlush");
	return if ($_[0] eq "2");
    }

    if ($param{'DBType'} =~ /^mysql|pg|postgres/i) {
	foreach $nick (keys %seencache) {
	    my $exists = &dbGet("seen","nick", $nick, "nick");

	    if (defined $exists and $exists) {
		&dbUpdate("seen", "nick", $nick, (
			"time" => $seencache{$nick}{'time'},
			"host" => $seencache{$nick}{'host'},
			"channel" => $seencache{$nick}{'chan'},
			"message" => $seencache{$nick}{'msg'},
		) );
		$stats{'old'}++;
	    } else {
		my $retval = &dbInsert("seen", $nick, (
			"nick" => $seencache{$nick}{'nick'},
			"time" => $seencache{$nick}{'time'},
			"host" => $seencache{$nick}{'host'},
			"channel" => $seencache{$nick}{'chan'},
			"message" => $seencache{$nick}{'msg'},
		) );
		$stats{'new'}++;

		### TODO: put bad nick into a list and don't do it again!
		&FIXME("Should never happen! (nick => $nick)") if !$retval;
	    }

	    delete $seencache{$nick};
	    $flushed++;
	}

    } elsif ($param{'DBType'} =~ /^dbm/i) {

	foreach $nick (keys %seencache) {
	    my $retval = &dbInsert("seen", $nick, (
		"nick" => $seencache{$nick}{'nick'},
		"time" => $seencache{$nick}{'time'},
		"host" => $seencache{$nick}{'host'},
		"channel" => $seencache{$nick}{'chan'},
		"message" => $seencache{$nick}{'msg'},
	    ) );

	    ### TODO: put bad nick into a list and don't do it again!
	    &FIXME("Should never happen! (nick => $nick)") if !$retval;

	    delete $seencache{$nick};
	    $flushed++;
	}
    } else {
	&DEBUG("seenFlush: NO VALID FACTOID SUPPORT?");
    }

    &status("Flushed $flushed seen entries.")		if ($flushed);
    &VERB(sprintf("  new seen: %03.01f%% (%d/%d)",
	$stats{'new'}*100/$stats{'count_old'},
	$stats{'new'}, $stats{'count_old'} ), 2)	if ($stats{'new'});
    &VERB(sprintf("  now seen: %3.1f%% (%d/%d)",
	$stats{'old'}*100/&countKeys("seen"),
	$stats{'old'}, &countKeys("seen") ), 2)		if ($stats{'old'});

    &WARN("scalar keys seenflush != 0!")	if (scalar keys %seenflush);

}

sub leakCheck {
    my ($blah1,$blah2);
    my $count = 0;

    if (@_) {
	&ScheduleThis(60, "leakCheck");
	&ScheduleChecked("leakCheck");
	return if ($_[0] eq "2");
    }

    # flood.
    foreach $blah1 (keys %flood) {
	foreach $blah2 (keys %{$flood{$blah1}}) {
	    $count += scalar(keys %{$flood{$blah1}{$blah2}});
	}
    }
    &VERB("\%flood has $count total keys.",2);

    my $chan;
    foreach $chan (grep /[A-Z]/, keys %channels) {
	&DEBUG("leak: chan => '$chan'.");
	my ($i,$j);
	foreach $i (keys %{$channels{$chan}}) {
	    foreach (keys %{$channels{$chan}{$i}}) {
		&DEBUG("leak:   \$channels{$chan}{$i}{$_} ...");
	    }
	}
    }
}

sub ignoreCheck {
    my $time	= time();
    my $count	= 0;

    foreach (keys %ignore) {
	my $chan = $_;

	foreach (keys %{ $ignore{$chan} }) {
	    my @array = $ignore{$chan}{$_};

	    foreach (@array) {
		&DEBUG("  => $_");
	    }

	    next;
	    next unless ($time > $ignore{$_});

	    delete $ignore{$chan}{$_};
	    &status("ignore: $_/$chan has expired.");
	    $count++;
	}
    }
    &VERB("ignore: $count items deleted.",2);

    &ScheduleThis(60, "ignoreCheck") if (@_);
}

sub ircCheck {
    my @array = grep !/^_default$/, keys %chanconf;
    my $iconf = scalar(@array);
    my $inow  = scalar(keys %channels);
    if ($iconf > 2 and $inow * 2 <= $iconf) {
	&FIXME("ircCheck: current channels * 2 <= config channels. FIXME.");
    }

    if (!$conn->connected and time - $msgtime > 3600) {
	&WARN("ircCheck: no msg for 3600 and disco'd! reconnecting!");
	$msgtime = time();	# just in case.
	&ircloop();
    }

    if ($ident !~ /^\Q$param{ircNick}\E$/) {
	&WARN("ircCheck: ident($ident) != param{ircNick}($param{IrcNick}).");
    }

    &joinNextChan();
	# if scalar @joinnext => join more channels
	# else check for chanserv.

    if (grep /^\s*$/, keys %channels) {
	&WARN("we have a NULL chan in hash channels? removing!");
	delete $channels{''};
	&status("channels now:");
	foreach (keys %channels) {
	    &status("  $_");
	}
    }

    ### USER FILE.
    if ($utime_userfile > $wtime_userfile and time() - $wtime_userfile > 3600) {
	&writeUserFile();
	$wtime_userfile = time();
    }
    ### CHAN FILE.
    if ($utime_chanfile > $wtime_chanfile and time() - $wtime_chanfile > 3600) {
	&writeChanFile();
	$wtime_chanfile	= time();
    }

    &ScheduleThis(240, "ircCheck") if (@_);
}

sub miscCheck {
    &ScheduleThis(240, "miscCheck") if (@_);

    # SHM check.
    my @ipcs;
    if ( -x "/usr/bin/ipcs") {
	@ipcs = `/usr/bin/ipcs`;
    } else {
	&WARN("ircCheck: no 'ipcs' binary.");
	return;
    }

    # shmid stale remove.
    foreach (@ipcs) {
	chop;

	# key, shmid, owner, perms, bytes, nattch
	next unless (/^(0x\d+) (\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+/);

	my ($shmid, $size) = ($2,$5);
	next unless ($shmid != $shm and $size == 2000);

###	&status("SHM: nuking shmid $shmid");
###	system("/usr/bin/ipcrm shm $shmid >/dev/null");
    }

    ### check modules if they've been modified. might be evil.
    &reloadAllModules();
}

sub shmFlush {
    if (@_) {
	&ScheduleThis(5, "shmFlush");
	&ScheduleChecked("shmFlush");
	return if ($_[0] eq "2");
    }

    my $shmmsg = &shmRead($shm);
    $shmmsg =~ s/\0//g;         # remove padded \0's.

    return if ($$ != $::bot_pid); # fork protection.

    foreach (split '\|\|', $shmmsg) {
	&VERB("shm: Processing '$_'.",2);

	if (/^DCC SEND (\S+) (\S+)$/) {
	    my ($nick,$file) = ($1,$2);
	    if (exists $dcc{'SEND'}{$who}) {
		&msg($nick,"DCC already active.");
	    } else {
		&DEBUG("shm: dcc sending $2 to $1.");
		$conn->new_send($1,$2);
		$dcc{'SEND'}{$who} = time();
	    }
	} elsif (/^SET FORKPID (\S+) (\S+)/) {
	    $forked{$1}{PID} = $2;
	} elsif (/^DELETE FORK (\S+)$/) {
	    delete $forked{$1};
	} elsif (/^EVAL (.*)$/) {
	    &DEBUG("evaling '$1'.");
	    eval $1;
	} else {
	    &DEBUG("shm: unknown msg. ($_)");
	}
    }

    &shmWrite($shm,"") if ($shmmsg ne "");
}

### this is semi-scheduled
sub getNickInUse {
    if ($ident eq $param{'ircNick'}) {
	&status("okay, got my nick back.");
	return;
    }

    &status("Trying to get my nick back.");
    &nick($param{'ircNick'});

    &ScheduleThis(5, "getNickInUse") if (@_);
}

sub uptimeCycle {
    &uptimeWriteFile();

    &ScheduleThis(60, "uptimeCycle") if (@_);
}

sub slashdotCycle {
    &ScheduleThis(60, "slashdotCycle") if (@_);
    &ScheduleChecked("slashdotCycle");
    return if ($_[0] eq "2");

    my @chans = &ChanConfList("slashdotAnnounce");
    return unless (scalar @chans);

    &Forker("slashdot", sub {
	my @data = &Slashdot::slashdotAnnounce();

	foreach (@chans) {
	    next unless (&::validChan($_));

	    &::status("sending slashdot update to $_.");
	    my $c = $_;
	    foreach (@data) {
		&notice($c, "Slashdot: $_");
	    }
	}
    } );
}

sub freshmeatCycle {
    &ScheduleThis(60, "freshmeatCycle") if (@_);
    &ScheduleChecked("freshmeatCycle");
    return if ($_[0] eq "2");

    my @chans = &ChanConfList("freshmeatAnnounce");
    return unless (scalar @chans);

    &Forker("freshmeat", sub {
	my $data = &Freshmeat::freshmeatAnnounce();

	foreach (@chans) {
	    next unless (&::validChan($_));

	    &::status("sending freshmeat update to $_.");
	    &msg($_, $data);
	}
    } );
}

sub kernelCycle {
    &ScheduleThis(240, "kernelCycle") if (@_);
    &ScheduleChecked("kernelCycle");
    return if ($_[0] eq "2");

    my @chans = &ChanConfList("kernelAnnounce");
    return unless (scalar @chans);

    &Forker("kernel", sub {
	my @data = &Kernel::kernelAnnounce();

	foreach (@chans) {
	    next unless (&::validChan($_));

	    &::status("sending kernel update to $_.");
	    my $c = $_;
	    foreach (@data) {
		&notice($c, "Kernel: $_");
	    }
	}
    } );
}

sub wingateCheck {
    return unless &IsParam("wingate");
    return unless ($param{'wingate'} =~ /^(.*\s+)?$chan(\s+.*)?$/i);

    ### FILE CACHE OF OFFENDING WINGATES.
    foreach (grep /^$host$/, @wingateBad) {
	&status("Wingate: RUNNING ON $host BY $who");
	&ban("*!*\@$host", "") if &IsParam("wingateBan");

	next unless (&IsParam("wingateKick"));
	&kick($who, "", $param{'wingateKick'})
    }

    ### RUN CACHE OF TRIED WINGATES.
    if (grep /^$host$/, @wingateCache) {
	push(@wingateNow, $host);	# per run.
	push(@wingateCache, $host);	# cache per run.
    } else {
	&DEBUG("Already scanned $host. good.");
    }

    my $interval = $param{'wingateInterval'} || 60;	# seconds.
    return if (defined $forked{'wingate'});
    return if (time() - $wingaterun <= $interval);
    return unless (scalar(keys %wingateToDo));

    $wingaterun = time();

    &Forker("wingate", sub { &Wingate::Wingates(keys %wingateToDo); } );
    undef @wingateNow;
}

### TODO.
sub wingateWriteFile {
    return unless (scalar @wingateCache);

    my $file = "$bot_base_dir/$param{'ircUser'}.wingate";
    if ($bot_pid != $$) {
	&DEBUG("wingateWriteFile: Reorganising!");

	open(IN, $file);
	while (<IN>) {
	    chop;
	    push(@wingateNow, $_);
	}
	close IN;

	# very lame hack.
	my %hash = map { $_ => 1 } @wingateNow;
	@wingateNow = sort keys %hash;
    }

    &DEBUG("wingateWF: writing...");
    open(OUT, ">$file");
    foreach (@wingateNow) {
	print OUT "$_\n";
    }
    close OUT;

    &ScheduleThis(60, "wingateWriteFile") if (@_);
}

sub factoidCheck {
    my @list = &searchTable("factoids", "factoid_key", "factoid_key", " #DEL#");
    my $stale = ($param{'factoidDeleteDelay'} || 7)*60*60*24;

    foreach (@list) {
	my $age = &getFactInfo($_, "modified_time");	
	next unless (time() - $age > $stale);

	my $fix = $_;
	$fix =~ s/ #DEL#$//g;
	&VERB("safedel: Removing $fix for good.",2);
	&delFactoid($_);
    }

    &ScheduleThis(1440, "factoidCheck") if (@_);
}

sub dccStatus {
    my $time = strftime("%H:%M", localtime(time()) );

    return unless (scalar keys %{ $DCC{CHAT} });

    foreach (keys %channels) {
	&DCCBroadcast("[$time] $_: $users members ($chops chops), $bans bans","+o");
    }

    &ScheduleThis(10, "dccStatus") if (@_);
}

sub schedulerSTUB {

    &ScheduleThis(TIME_IN_MINUTES, "FUNCTION") if (@_);
}

sub scheduleList {
    ###
    # custom:
    #	a - time == now.
    #	b - weird time.
    ###

    &DEBUG("sched:");
    foreach (keys %{ $irc->{_queue} }) {
	my $q = $_;

	my $sched;
	foreach (keys %sched) {
	    next unless ($q eq $sched{$_});
	    $sched = $_;
	    last;
	}

	my $time = $irc->{_queue}->{$q}->[0] - time();

	if (defined $sched) {
	    &DEBUG("   $sched($q): ".&Time2String($time) );
	} else {
	    &DEBUG("   NULL($q): ".&Time2String($time) );
	}
    }

    &DEBUG("end of sList.");
}

sub getChanConfDefault {
    my($what, $chan, $default) = @_;

    if (exists $param{$what}) {
	return $param{$what};
    }

    my $val = &getChanConf($what, $chan);
    if (defined $val) {
	return $val;
    }
    &DEBUG("returning default $default for $what");
    ### TODO: set some vars?
    return $default;
}

1;
