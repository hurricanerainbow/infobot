#
# ProcessExtra.pl: Extensions to Process.pl
#          Author: dms
#         Version: v0.3 (20000707)
#         Created: 20000117
#

if (&IsParam("useStrict")) { use strict; }

sub setupSchedulers {
    &VERB("Starting schedulers...",2);

    # ONCE OFF.

    # REPETITIVE.
    &uptimeCycle(1)	if (&IsParam("uptime"));
    &randomQuote(1)	if (&IsParam("randomQuote"));
    &randomFactoid(1)	if (&IsParam("randomFactoid"));
    &logCycle(1)	if ($loggingstatus and &IsParam("logFile") and &IsParam("maxLogSize"));
    &limitCheck(1)	if (&IsParam("limitcheck"));
    &netsplitCheck(1);	# mandatory
    &floodCycle(1);	# mandatory
    &seenFlush(1)	if (&IsParam("seen") and &IsParam("seenFlushInterval"));
    &leakCheck(1);	# mandatory
    &ignoreListCheck(1);# mandatory
    &seenFlushOld(1)	if (&IsParam("seen"));
    &ircCheck(1);	# mandatory
    &shmFlush(1);	# mandatory
    &slashdotCycle(1)	if (&IsParam("slashdot") and &IsParam("slashdotAnnounce"));
    &freshmeatCycle(1)	if (&IsParam("freshmeat") and &IsParam("freshmeatAnnounce"));
    &kernelCycle(1)	if (&IsParam("kernel") and &IsParam("kernelAnnounce"));
    &wingateWriteFile(1) if (&IsParam("wingate"));
}

sub ScheduleThis {
    my ($interval, $codename, @args) = @_;
    my $waittime = &getRandomInt($interval);

    &VERB("Scheduling \&$codename() for ".&Time2String($waittime),3);
    $conn->schedule($waittime, \&$codename, @args);
}

sub randomQuote {
    my $line = &getRandomLineFromFile($bot_misc_dir. "/blootbot.randtext");
    if (!defined $line) {
	&ERROR("random Quote: weird error?");
	return;
    }

    my @channels = split(/[\s\t]+/, lc $param{'randomQuoteChannels'});
    @channels    = keys(%channels) unless (scalar @channels);

    my $good = 0;
    foreach (@channels) {
	next unless (&validChan($_));

	&status("sending random Quote to $_.");
	&action($_, "Ponders: ".$line);
	$good++;
    }

    if (!$good) {
	&WARN("randomQuote: no valid channels?");
	return;
    }

    my $interval = $param{'randomQuoteInterval'} || 60;
    &ScheduleThis($interval, "randomQuote") if (@_);
}

sub randomFactoid {
    my ($key,$val);
    my $error = 0;
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

    my @channels = split(/[\s\t]+/, lc $param{'randomFactoidChannels'});
    @channels    = keys(%channels) unless (scalar @channels);

    my $good = 0;
    foreach (@channels) {
	next unless (&validChan($_));

	&status("sending random Factoid to $_.");
###	&msg($_, "$key is $val");
	&action($_, "Thinks: \037$key\037 is $val");
	### FIXME: Use &getReply() on above to format factoid properly?
	$good++;
    }

    if (!$good) {
	&WARN("randomFactoid: no valid channels?");
	return;
    }

    my $interval = $param{'randomFactoidInterval'} || 60;
    &ScheduleThis($interval, "randomFactoid") if (@_);
}

sub logCycle {
    # check if current size is too large.
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

    # check if all the logs exceed size.
    my $logdir = "$bot_base_dir/log/";
    if (opendir(LOGS, $logdir)) {
	my $tsize = 0;
	my (%age, %size);

	while (defined($_ = readdir LOGS)) {
	    my $logfile = "$logdir/$_";

	    next unless ( -f $logfile);
	    my $size = -s $logfile;
	    my $age = (stat $logfile)[9]; ### or 8 ?

	    $age{$age}		= $logfile;
	    $size{$logfile}	= $size;

	    $tsize		+= $size;
	}
	closedir LOGS;

	my $delete = 0;
	while ($tsize > $param{'maxLogSize'}) {
	    &status("LOG: current size > max ($tsize > $param{'maxLogSize'})");
	    my $oldest = (sort {$a <=> $b} keys %age)[0];
	    &status("LOG: unlinking $age{$oldest}.");
	    ### NOT YET.
	    # unlink $age{$oldest};
	    $tsize -= $oldest;
	    $delete++;
	}

	### TODO: add how many b,kb,mb removed?
	if ($delete) {
	    &status("LOG: removed $delete logs.");
	}
    } else {
	&WARN("could not open dir $logdir");
    }

    &ScheduleThis(60, "logCycle") if (@_);
}

sub seenFlushOld {
    my $max_time = $param{'seenMaxDays'}*60*60*24;
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

    &ScheduleThis(1440, "seenFlushOld") if (@_);
}

sub limitCheck {
    my $limitplus = $param{'limitcheckPlus'} || 5;

    if (scalar keys %netsplit) {
	&status("limitcheck: netsplit active.");
	return;
    }

    my @channels = split(/[\s\t]+/, lc $param{'limitcheck'});

    foreach (@channels) {
	next unless (&validChan($_));

	if (!exists $channels{$_}{'o'}{$ident}) {
	    &ERROR("limitcheck: dont have ops on $_.");
	    next;
	}

	my $newlimit = scalar(keys %{$channels{$_}{''}}) + $limitplus;
	my $limit = $channels{$_}{'l'};

	next unless (!defined $limit or $limit != $newlimit);

	&rawout("MODE $_ +l $newlimit");
    }

    my $interval = $param{'limitcheckInterval'} || 10;
    &ScheduleThis($interval, "limitCheck") if (@_);
}

sub netsplitCheck {
    my ($s1,$s2);

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

	if (!&IsNickInAnyChan($_)) {
	    &DEBUG("netsplitC: $_ didn't come back from netsplit in 2 hours; removing from netsplit list.");
	    delete $netsplit{$_};
	}
    }

    &ScheduleThis(30, "netsplitCheck") if (@_);
}

sub floodCycle {
    my $interval = $param{'floodInterval'} || 60;	# seconds.
    my $delete = 0;

    my $who;
    foreach $who (keys %flood) {
	foreach (keys %{$flood{$who}}) {
	    if (time() - $flood{$who}{$_} > $interval) {
		delete $flood{$who}{$_};
		$delete++;
	    }
	}
    }
    &VERB("floodCycle: deleted $delete items.",2);

    &ScheduleThis($interval, "floodCycle") if (@_);	# minutes.
}

sub seenFlush {
    my $nick;
    my $flushed = 0;

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
	    } else {
		my $retval = &dbInsert("seen", $nick, (
			"nick" => $seencache{$nick}{'nick'},
			"time" => $seencache{$nick}{'time'},
			"host" => $seencache{$nick}{'host'},
			"channel" => $seencache{$nick}{'chan'},
			"message" => $seencache{$nick}{'msg'},
		) );

		### TODO: put bad nick into a list and don't do it again!
		if ($retval == 0) {
		    &ERROR("Should never happen! (nick => $nick) FIXME");
		}
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
	    if ($retval == 0) {
		&ERROR("Should never happen! (nick => $nick) FIXME");
	    }

	    delete $seencache{$nick};
	    $flushed++;
	}
    } else {
	&DEBUG("seenFlush: NO VALID FACTOID SUPPORT?");
    }

    &VERB("Flushed $flushed seen entries.",2);

    my $interval = $param{'seenFlushInterval'} || 60;
    &ScheduleThis($interval, "seenFlush") if (@_);
}

sub leakCheck {
    my ($blah1,$blah2);
    my $count = 0;

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

    &ScheduleThis(60, "leakCheck") if (@_);
}

sub ignoreListCheck {
    my $time = time();
    my $count = 0;

    foreach (keys %ignoreList) {
	next if ($ignoreList{$_} == 1);
	next unless ($time > $ignoreList{$_});

	delete $ignoreList{$_};
	&status("ignore: $_ has expired.");
	$count++;
    }
    &VERB("ignore: $count items deleted.",2);

    &ScheduleThis(30, "ignoreListCheck") if (@_);
}

sub ircCheck {
    my @array = split /[\t\s]+/, $param{'join_channels'};
    my $iconf = scalar(@array);
    my $inow  = scalar(keys %channels);
    if ($iconf > 2 and $inow * 2 <= $iconf) {
	&FIXME("ircCheck: current channels * 2 <= config channels. FIXME.");
    }

    my @ipcs;
    if ( -x "/usr/bin/ipcs") {
	@ipcs = `/usr/bin/ipcs`;
    } else {
	&WARN("ircCheck: no 'ipcs' binary.");
    }

    # shmid stale remove.
    foreach (@ipcs) {
	chop;

	# key, shmid, owner, perms, bytes, nattch
	next unless (/^(0x\d+) (\d+)\s+(\S+)\s+(\d+)\s+(\d+)\s+/);

	my ($shmid, $size) = ($2,$5);
	next unless ($shmid != $shm and $size == 2000);

	&status("SHM: nuking shmid $shmid");
	system("/usr/bin/ipcrm shm $shmid >/dev/null");
    }

    if (!$conn->connected and time - $msgtime > 3600) {
	&WARN("ircCheck: no msg for 3600 and disco'd! reconnecting!");
	$msgtime = time();	# just in case.
	&ircloop();
    }

    if ($ident !~ /^\Q$param{ircNick}\E$/) {
	&WARN("ircCheck: ident($ident) != param{ircNick}($param{IrcNick}).");
    }

    if (scalar @joinchan) {
	&WARN("We have some channels to join, doing so.");
	&joinNextChan();
    }

    &ScheduleThis(240, "ircCheck") if (@_);
}

sub shmFlush {
    my $shmmsg = &shmRead($shm);
    $shmmsg =~ s/\0//g;         # remove padded \0's.

    foreach (split '\|\|', $shmmsg) {
	&status("shm: Processing '$_'.");

	if (/^DCC SEND (\S+) (\S+)$/) {
	    my ($nick,$file) = ($1,$2);
	    if (exists $dcc{'SEND'}{$who}) {
		&msg($nick,"DCC already active.");
	    } else {
		&DEBUG("shm: dcc sending $2 to $1.");
		$conn->new_send($1,$2);
		$dcc{'SEND'}{$who} = time();
	    }
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

    &ScheduleThis(5, "shmFlush") if (@_);
}

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
    &Forker("slashdot", sub { &Slashdot::slashdotAnnounce(); } );

    &ScheduleThis(60, "slashdotCycle") if (@_);
}

sub freshmeatCycle {
    &Forker("freshmeat", sub { &Freshmeat::freshmeatAnnounce(); } );

    &ScheduleThis(60, "freshmeatCycle") if (@_);
}

sub kernelCycle {
    &Forker("kernel", sub { &Kernel::kernelAnnounce(); } );

    &ScheduleThis(240, "kernelCycle") if (@_);
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

1;
