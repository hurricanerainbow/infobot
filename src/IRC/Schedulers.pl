#
# ProcessExtra.pl: Extensions to Process.pl
#          Author: dms
#         Version: v0.5 (20010124)
#         Created: 20000117
#

if (&IsParam("useStrict")) { use strict; }

use POSIX qw(strftime);
use vars qw(%sched);

sub setupSchedulers {
    &VERB("Starting schedulers...",2);

    # ONCE OFF.

    # REPETITIVE.
    # 1 for run straight away, 2 for on next-run.
    &uptimeLoop(1);
    &randomQuote(2);
    &randomFactoid(2);
    &randomFreshmeat(2);
    &logLoop(1);
    &chanlimitCheck(1);
    &netsplitCheck(1);	# mandatory
    &floodLoop(1);	# mandatory
    &seenFlush(2);
    &leakCheck(2);	# mandatory
    &ignoreCheck(1);	# mandatory
    &seenFlushOld(2);
    &ircCheck(1);	# mandatory
    &miscCheck(1);	# mandatory
    &miscCheck2(2);	# mandatory
    &shmFlush(1);	# mandatory
    &slashdotLoop(2);
    &plugLoop(2);
    &freshmeatLoop(2);
    &kernelLoop(2);
    &wingateWriteFile(2);
    &factoidCheck(2);	# takes a couple of seconds on a 486. defer it
    &newsFlush(1);

#    my $count = map { exists $sched{$_}{TIME} } keys %sched;
    my $count	= 0;
    foreach (keys %sched) {
#	next unless (exists $sched{$_}{TIME});
	my $time = $sched{$_}{TIME};
	next unless (defined $time and $time > time());

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

    my $time = $sched{$codename}{TIME};
    if (defined $time and $time > time()) {
	&WARN("Sched for $codename already exists.");
	return;
    }

#    &VERB("Scheduling \&$codename() for ".&Time2String($waittime),3);

    my $retval = $conn->schedule($waittime, \&$codename, @args);
    $sched{$codename}{LABEL}	= $retval;
    $sched{$codename}{TIME}	= time()+$waittime;
    $sched{$codename}{LOOP}	= 1;
}

####
#### LET THE FUN BEGIN.
####

sub randomQuote {
    my $interval = &getChanConfDefault("randomQuoteInterval", 60);
    if (@_) {
	&ScheduleThis($interval, "randomQuote");
	return if ($_[0] eq "2");	# defer.
    }

    my $line = &getRandomLineFromFile($bot_data_dir. "/blootbot.randtext");
    if (!defined $line) {
	&ERROR("random Quote: weird error?");
	return;
    }

    foreach ( &ChanConfList("randomQuote") ) {
	next unless (&validChan($_));

	&status("sending random Quote to $_.");
	&action($_, "Ponders: ".$line);
    }
    ### TODO: if there were no channels, don't reschedule until channel
    ###		configuration is modified.
}

sub randomFactoid {
    my ($key,$val);
    my $error = 0;

    my $interval = &getChanConfDefault("randomFactoidInterval", 60);
    if (@_) {
	&ScheduleThis($interval, "randomFactoid");
	return if ($_[0] eq "2");	# defer.
    }

    while (1) {
	($key,$val) = &randKey("factoids","factoid_key,factoid_value");
###	$val =~ tr/^[A-Z]/[a-z]/;	# blah is Good => blah is good.
	last if (defined $val and $val !~ /^</);

	$error++;
	if ($error == 5) {
	    &ERROR("rF: tried 5 times but failed.");
	    return;
	}
    }

    foreach ( &ChanConfList("randomFactoid") ) {
	next unless (&validChan($_));

	&status("sending random Factoid to $_.");
	&action($_, "Thinks: \037$key\037 is $val");
	### FIXME: Use &getReply() on above to format factoid properly?
	$good++;
    }
}

sub randomFreshmeat {
    my $interval = &getChanConfDefault("randomFresheatInterval", 60);

    if (@_) {
	&ScheduleThis($interval, "randomFreshmeat");
	return if ($_[0] eq "2");	# defer.
    }

    my @chans = &ChanConfList("randomFreshmeat");
    return unless (scalar @chans);

    &Forker("freshmeat", sub {
	my $retval = &Freshmeat::randPackage();

	foreach (@chans) {
	    next unless (&validChan($_));

	    &status("sending random Freshmeat to $_.");
	    &say($_, $line);
	}
    } );
}

sub logLoop {
    if (@_) {
	&ScheduleThis(60, "logLoop");
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
	CORE::system("/bin/mv '$param{'logfile'}' '$file{log}'");
	&compress($file{log});
	&openLog();
	&status("cycling log file.");
    }

    ### check if all the logs exceed size.
    if (!opendir(LOGS, $bot_log_dir)) {
	&WARN("logLoop: could not open dir '$bot_log_dir'");
	return;
    }

    my $tsize		= 0;
    my (%age, %size);
    while (defined($_ = readdir LOGS)) {
	my $logfile	= "$bot_log_dir/$_";

	next unless ( -f $logfile);

	my $size	= -s $logfile;
	my $age		= (stat $logfile)[9];
	$age{$age}	= $logfile;
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
	$tsize		-= $oldest;
	$delete++;
    }

    ### TODO: add how many b,kb,mb removed?
    &status("LOG: removed $delete logs.") if ($delete);
}

sub seenFlushOld {
    if (@_) {
	&ScheduleThis(1440, "seenFlushOld");
	return if ($_[0] eq "2");	# defer.
    }

    # is this global-only?
    return unless (&IsChanConf("seen") > 0);
    return unless (&IsChanConf("seenFlushInterval") > 0);

    # global setting. does not make sense for per-channel.
    my $max_time = &getChanConfDefault("seenMaxDays", 30) *60*60*24;
    my $delete   = 0;

    if ($param{'DBType'} =~ /^pgsql|mysql|sqlite/i) {
	my $query;

	if ($param{'DBType'} =~ /^mysql|sqlite$/i) {
	    $query = "SELECT nick,time FROM seen GROUP BY nick HAVING ".
			"UNIX_TIMESTAMP() - time > $max_time";
	} else {	# pgsql.
	    $query = "SELECT nick,time FROM seen WHERE ".
		"extract(epoch from timestamp 'now') - time > $max_time";
	}

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
	    my $delta_time = $time - &dbGet("seen", "time", "nick", $_);
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

sub newsFlush {
    if (@_) {
	&ScheduleThis(60, "newsFlush");
	return if ($_[0] eq "2");	# defer.
    }

    if (!&ChanConfList("news")) {
	&DEBUG("newsFlush: news disabled? (chan => $chan)");
	return;
    }

    my $delete	= 0;
    my $oldest	= time();
    my %none;
    foreach $chan (keys %::news) {
	my $i		= 0;
	my $total	= scalar(keys %{ $::news{$chan} });

	if (!$total) {
	    delete $::news{$chan};
	    next;
	}

	foreach $item (keys %{ $::news{$chan} }) {
	    my $t = $::news{$chan}{$item}{Expire};

	    my $tadd	= $::news{$chan}{$item}{Time};
	    $oldest	= $tadd if ($oldest > $tadd);

	    next if ($t == 0 or $t == -1);
	    if ($t < 1000) {
		&status("newsFlush: Fixed Expire time for $chan/$item, should not happen anyway.");
		$::news{$chan}{$item}{Expire} = time() + $t*60*60*24;
		next;
	    }

	    my $delta = $t - time();

	    next unless (time() > $t);

	    # todo: show how old it was.
	    delete $::news{$chan}{$item};
	    &status("NEWS: (newsflush) deleted '$item'");
	    $delete++;
	    $i++;
	}

	&status("NEWS (newsflush) {$chan}: deleted [$i/$total] news entries.") if ($i);
	$none{$chan} = 1 if ($total == $i);
    }

    # todo: flush users aswell.
    my $duser	= 0;
    foreach $chan (keys %::newsuser) {
	next if (exists $none{$chan});

	foreach (keys %{ $::newsuser{$chan} }) {
	    my $t = $::newsuser{$chan}{$_};
	    if (!defined $t or ($t > 2 and $t < 1000)) {
		&DEBUG("something wrong with newsuser{$chan}{$_} => $t");
		next;
	    }

	    next unless ($oldest > $t);

	    delete $::newsuser{$chan}{$_};
	    $duser++;
	}

	my $i = scalar(keys %{ $::newsuser{$chan} });
	delete $::newsuser{$chan} unless ($i);
    }

    if ($delete or $duser) {
	&News::writeNews();
	&status("NewsFlush: deleted: $delete news entries; $duser user cache.");
    }
}

sub chanlimitCheck {
    my $interval = &getChanConfDefault("chanlimitcheckInterval", 10);

    if (@_) {
	&ScheduleThis($interval, "chanlimitCheck");
	return if ($_[0] eq "2");
    }

    my $str = join(' ', &ChanConfList("chanlimitcheck") );

    foreach $chan ( &ChanConfList("chanlimitcheck") ) {
	next unless (&validChan($chan));

	if ($chan eq "_default") {
	    &WARN("chanlimit: we're doing $chan!! HELP ME!");
	    next;
	}

	my $limitplus	= &getChanConfDefault("chanlimitcheckPlus", 5, $chan);
	my $newlimit	= scalar(keys %{ $channels{$chan}{''} }) + $limitplus;
	my $limit	= $channels{$chan}{'l'};

	if (scalar keys %netsplitservers) {
	    if (defined $limit) {
		&status("chanlimit: netsplit; removing it for $chan.");
		$conn->mode($chan, "-l");
		$cache{chanlimitChange}{$chan} = time();
		&status("chanlimit: netsplit; removed.");
	    }

	    next;
	}

	if (defined $limit and scalar keys %{ $channels{$chan}{''} } > $limit) {
	    &FIXME("LIMIT: set too low!!! FIXME");
	    ### run NAMES again and flush it.
	}

	if (defined $limit and $limit == $newlimit) {
	    $cache{chanlimitChange}{$chan} = time();
	    next;
	}

	if (!exists $channels{$chan}{'o'}{$ident}) {
	    &status("chanlimit: dont have ops on $chan.") unless (exists $cache{warn}{chanlimit}{$chan});
	    $cache{warn}{chanlimit}{$chan} = 1;
	    &chanServCheck($chan);
	    next;
	}
	delete $cache{warn}{chanlimit}{$chan};

	if (!defined $limit) {
	    &status("chanlimit: setting for first time or from netsplit, for $chan");
	}

	if (exists $cache{chanlimitChange}{$chan}) {
	    my $delta = time() - $cache{chanlimitChange}{$chan};
	    if ($delta < $interval*60) {
		&DEBUG("chanlimit: not going to change chanlimit! ($delta<$interval*60)");
		return;
	    }
	}

	$conn->mode($chan, "+l", $newlimit);
	$cache{chanlimitChange}{$chan} = time();
    }
}

sub netsplitCheck {
    my ($s1,$s2);

    if (@_) {
	&ScheduleThis(15, "netsplitCheck");
	return if ($_[0] eq "2");
    }

    $cache{'netsplitCache'}++;
#    &DEBUG("running netsplitCheck... $cache{netsplitCache}");

    if (!scalar %netsplit and scalar %netsplitservers) {
	&DEBUG("nsC: !hash netsplit but hash netsplitservers <- removing!");
	undef %netsplitservers;
	return;
    }

    # well... this shouldn't happen since %netsplit code does it anyway.
    foreach $s1 (keys %netsplitservers) {

	foreach $s2 (keys %{ $netsplitservers{$s1} }) {
	    my $delta = time() - $netsplitservers{$s1}{$s2};

	    if ($delta > 60*30) {
		&status("netsplit between $s1 and $s2 appears to be stale.");
		delete $netsplitservers{$s1}{$s2};
		&chanlimitCheck();
	    }
	}

	my $i = scalar(keys %{ $netsplitservers{$s1} });
	delete $netsplitservers{$s1} unless ($i);
    }

    # %netsplit hash checker.
    my $count	= scalar keys %netsplit;
    my $delete	= 0;
    foreach (keys %netsplit) {
	if (&IsNickInAnyChan($_)) {	# why would this happen?
#	    &DEBUG("nsC: $_ is in some chan; removing from netsplit list.");
	    delete $netsplit{$_};
	    $delete++;
	    next;
	}

	next unless (time() - $netsplit{$_} > 60*15);

	$delete++;
	delete $netsplit{$_};
    }

    # yet another hack.
    foreach (keys %channels) {
	my $i = $cache{maxpeeps}{$chan} || 0;
	my $j = scalar(keys %{ $channels{$chan} });
	next unless ($i > 10 and 0.25*$i > $j);

	&DEBUG("netsplit: 0.25*max($i) > current($j); possible netsplit?");
    }

    if ($delete) {
	my $j = scalar(keys %netsplit);
	&status("nsC: removed from netsplit list: (before: $count; after: $j)");
    }

    if (!scalar %netsplit and scalar %netsplitservers) {
	&DEBUG("nsC: ok hash netsplit is NULL; purging hash netsplitservers");
	undef %netsplitservers;
    }

    if ($count and !scalar keys %netsplit) {
	&DEBUG("nsC: netsplit is hopefully gone. reinstating chanlimit check.");
	&chanlimitCheck();
    }
}

sub floodLoop {
    my $delete   = 0;
    my $who;

    if (@_) {
	&ScheduleThis(60, "floodLoop");	# minutes.
	return if ($_[0] eq "2");
    }

    my $time		= time();
    my $interval	= &getChanConfDefault("floodCycle",60);

    foreach $who (keys %flood) {
	foreach (keys %{ $flood{$who} }) {
	    if (!exists $flood{$who}{$_}) {
		&WARN("flood{$who}{$_} undefined?");
		next;
	    }

	    if ($time - $flood{$who}{$_} > $interval) {
		delete $flood{$who}{$_};
		$delete++;
	    }
	}
    }
    &VERB("floodLoop: deleted $delete items.",2);
}

sub seenFlush {
    if (@_) {
	my $interval = &getChanConfDefault("seenFlushInterval", 60);
	&ScheduleThis($interval, "seenFlush");
	return if ($_[0] eq "2");
    }

    my %stats;
    my $nick;
    my $flushed 	= 0;
    $stats{'count_old'} = &countKeys("seen") || 0;
    $stats{'new'}	= 0;
    $stats{'old'}	= 0;

    if ($param{'DBType'} =~ /^(mysql|pgsql|sqlite)$/i) {
	foreach $nick (keys %seencache) {
	    my $retval = &dbReplace("seen", "nick", (
			"nick" => lc $seencache{$nick}{'nick'},
			"time" => $seencache{$nick}{'time'},
			"host" => $seencache{$nick}{'host'},
			"channel" => $seencache{$nick}{'chan'},
			"message" => $seencache{$nick}{'msg'},
	    ) );
	    delete $seencache{$nick};
	    $flushed++;

	    next;

	    ###
	    ### old code.
	    ###

	    my $exists = &dbGet("seen", "nick", "nick=".&dbQuote($nick) );

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

    &status("Seen: Flushed $flushed entries.")	if ($flushed);
    &VERB(sprintf("  new seen: %03.01f%% (%d/%d)",
	$stats{'new'}*100/($stats{'count_old'} || 1),
	$stats{'new'}, ( $stats{'count_old'} || 1) ), 2) if ($stats{'new'});
    &VERB(sprintf("  now seen: %3.1f%% (%d/%d)",
	$stats{'old'}*100 / ( &countKeys("seen") || 1),
	$stats{'old'}, &countKeys("seen") ), 2)		if ($stats{'old'});

    &WARN("scalar keys seenflush != 0!")	if (scalar keys %seenflush);
}

sub leakCheck {
    my ($blah1,$blah2);
    my $count = 0;

    if (@_) {
	&ScheduleThis(240, "leakCheck");
	return if ($_[0] eq "2");
    }

    # flood. this is dealt with in floodLoop()
    foreach $blah1 (keys %flood) {
	foreach $blah2 (keys %{ $flood{$blah1} }) {
	    $count += scalar(keys %{ $flood{$blah1}{$blah2} });
	}
    }
    &VERB("leak: hash flood has $count total keys.",2);

    # floodjoin.
    $count = 0;
    foreach $blah1 (keys %floodjoin) {
	foreach $blah2 (keys %{ $floodjoin{$blah1} }) {
	    $count += scalar(keys %{ $floodjoin{$blah1}{$blah2} });
	}
    }
    &VERB("leak: hash floodjoin has $count total keys.",2);

    # floodwarn.
    $count = scalar(keys %floodwarn);
    &VERB("leak: hash floodwarn has $count total keys.",2);

    my $chan;
    foreach $chan (grep /[A-Z]/, keys %channels) {
	&DEBUG("leak: chan => '$chan'.");
	my ($i,$j);
	foreach $i (keys %{ $channels{$chan} }) {
	    foreach (keys %{ $channels{$chan}{$i} }) {
		&DEBUG("leak:   \$channels{$chan}{$i}{$_} ...");
	    }
	}
    }

    # chanstats
    $count = scalar(keys %chanstats);
    &VERB("leak: hash chanstats has $count total keys.",2);

    # nuh.
    my $delete	= 0;
    foreach (keys %nuh) {
	next if (&IsNickInAnyChan($_));
	next if (exists $dcc{CHAT}{$_});

	delete $nuh{$_};
	$delete++;
    }

    &status("leak: $delete nuh{} items deleted; now have ".
				scalar(keys %nuh) ) if ($delete);
}

sub ignoreCheck {
    if (@_) {
	&ScheduleThis(60, "ignoreCheck");
	return if ($_[0] eq "2");	# defer.
    }

    my $time	= time();
    my $count	= 0;

    foreach (keys %ignore) {
	my $chan = $_;

	foreach (keys %{ $ignore{$chan} }) {
	    my @array = @{ $ignore{$chan}{$_} };

	    next unless ($array[0] and $time > $array[0]);

	    delete $ignore{$chan}{$_};
	    &status("ignore: $_/$chan has expired.");
	    $count++;
	}
    }

    $cache{ignoreCheckTime} = time();

    &VERB("ignore: $count items deleted.",2);
}

sub ircCheck {
    if (@_) {
	&ScheduleThis(15, "ircCheck");
	return if ($_[0] eq "2");	# defer.
    }

    $cache{statusSafe} = 1;

    my @x	= &getJoinChans();
    my $iconf	= scalar( @x );
    my $inow	= scalar( keys %channels );
    if ($iconf > 2 and $inow * 2 <= $iconf) {
	&FIXME("ircCheck: current channels * 2 <= config channels. FIXME.");
	&FIXME("ircCheck: iconf = $iconf");
	&FIXME("ircCheck: inow  = $inow");
#	@joinchan	= @x;
	&joinNextChan();
    }

    if (!$conn->connected or time() - $msgtime > 3600) {
	# todo: shouldn't we use cache{connect} somewhere?
	if (exists $cache{connect}) {
	    &WARN("ircCheck: no msg for 3600 and disco'd! reconnecting!");
	    $msgtime = time();	# just in case.
	    &ircloop();
	    delete $cache{connect};
	} else {
	    &status("IRCTEST: possible lost in space; checking. ".
		scalar(localtime) );
	    &msg($ident, "TEST");
	    $cache{connect} = time();
	}
    }

    if ($ident !~ /^\Q$param{ircNick}\E$/) {
	# this does not work unfortunately.
	&WARN("ircCheck: ident($ident) != param{ircNick}($param{IrcNick}).");

	# this check is misleading... perhaps we should do a notify.
	if (! &IsNickInAnyChan( $param{ircNick} ) ) {
	    &DEBUG("$param{ircNick} not in use... changing!");
	    &nick( $param{ircNick} );
	} else {
	    &WARN("$param{ircNick} is still in use...");
	}
    }

    if (grep /^\s*$/, keys %channels) {
	&WARN("ircCheck: we have a NULL chan in hash channels? removing!");
	if (!exists $channels{''}) {
	    &DEBUG("ircCheck: this should never happen!");
	}

	delete $channels{''};
    }

    $cache{statusSafe} = 0;

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
}

sub miscCheck {
    if (@_) {
	&ScheduleThis(120, "miscCheck");
	return if ($_[0] eq "2");	# defer.
    }

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
	my $z	= &shmRead($shmid);
	if ($z =~ /^(\d+): /) {
	    my $time	= $1;
	    next if (time() - $time < 60*60);

	} else {
#	    &DEBUG("shm: $shmid is not ours or old blootbot => ($z)");
#	    next;
	}

	&status("SHM: nuking shmid $shmid");
	CORE::system("/usr/bin/ipcrm shm $shmid >/dev/null");
    }

    # make backup of important files.
    &mkBackup( $bot_state_dir."/blootbot.chan", 60*60*24*3);
    &mkBackup( $bot_state_dir."/blootbot.users", 60*60*24*3);
    &mkBackup( $bot_base_dir."/blootbot-news.txt", 60*60*24*1);

    # flush cache{lobotomy}
    foreach (keys %{ $cache{lobotomy} }) {
	next unless (time() - $cache{lobotomy}{$_} > 60*60);
	delete $cache{lobotomy}{$_};
    }

    ### check modules if they've been modified. might be evil.
    &reloadAllModules();
}

sub miscCheck2 {
    if (@_) {
	&ScheduleThis(240, "miscCheck2");
	return if ($_[0] eq "2");	# defer.
    }

    # debian check.
    opendir(DEBIAN, "$bot_state_dir/debian");
    foreach ( grep /gz$/, readdir(DEBIAN) ) {
	my $exit = CORE::system("gzip -t $bot_state_dir/debian/$_");
	next unless ($exit);

	&status("debian: unlinking file => $_");
	unlink "$bot_state_dir/debian/$_";
    }
    closedir DEBIAN;

    # compress logs that should have been compressed.
    # todo: use strftime?
    my ($day,$month,$year) = (localtime(time()))[3,4,5];
    my $date = sprintf("%04d%02d%02d",$year+1900,$month+1,$day);

    if (!opendir(DIR,"$bot_log_dir")) {
	&ERROR("misccheck2: log dir $bot_log_dir does not exist.");
	closedir DIR;
	return -1;
    }

    while (my $f = readdir(DIR)) {
	next unless ( -f "$bot_log_dir/$f");
	next if ($f =~ /gz|bz2/);
	next unless ($f =~ /(\d{8})/);
	next if ($date eq $1);

	&compress("$bot_log_dir/$f");
    }
    closedir DIR;
}

### this is semi-scheduled
sub getNickInUse {
    if ($ident eq $param{'ircNick'}) {
	&status("okay, got my nick back.");
	return;
    }

    if (@_) {
	&ScheduleThis(30, "getNickInUse");
	return if ($_[0] eq "2");	# defer.
    }

    &nick( $param{'ircNick'} );
}

sub uptimeLoop {
    return unless &IsChanConf("uptime");

    if (@_) {
	&ScheduleThis(60, "uptimeLoop");
	return if ($_[0] eq "2");	# defer.
    }

    &uptimeWriteFile();
}

sub slashdotLoop {

    if (@_) {
	&ScheduleThis(60, "slashdotLoop");
	return if ($_[0] eq "2");
    }

    my @chans = &ChanConfList("slashdotAnnounce");
    return unless (scalar @chans);

    &Forker("slashdot", sub {
	my $line = &Slashdot::slashdotAnnounce();
	return unless (defined $line);

	foreach (@chans) {
	    next unless (&::validChan($_));

	    &::status("sending slashdot update to $_.");
	    &notice($_, "Slashdot: $line");
	}
    } );
}

sub plugLoop {

    if (@_) {
	&ScheduleThis(60, "plugLoop");
	return if ($_[0] eq "2");
    }

    my @chans = &ChanConfList("plugAnnounce");
    return unless (scalar @chans);

    &Forker("plug", sub {
	my $line = &Plug::plugAnnounce();
	return unless (defined $line);

	foreach (@chans) {
	    next unless (&::validChan($_));

	    &::status("sending plug update to $_.");
	    &notice($_, "Plug: $line");
	}
    } );
}

sub freshmeatLoop {
    if (@_) {
	&ScheduleThis(60, "freshmeatLoop");
	return if ($_[0] eq "2");
    }

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

sub kernelLoop {
    if (@_) {
	&ScheduleThis(240, "kernelLoop");
	return if ($_[0] eq "2");
    }

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
    return unless &IsChanConf("wingate");

    ### FILE CACHE OF OFFENDING WINGATES.
    foreach (grep /^$host$/, @wingateBad) {
	&status("Wingate: RUNNING ON $host BY $who");
	&ban("*!*\@$host", "") if &IsChanConf("wingateBan");

	my $reason	= &getChanConf("wingateKick");

	next unless ($reason);
	&kick($who, "", $reason)
    }

    ### RUN CACHE OF TRIED WINGATES.
    if (grep /^$host$/, @wingateCache) {
	push(@wingateNow, $host);	# per run.
	push(@wingateCache, $host);	# cache per run.
    } else {
	&DEBUG("Already scanned $host. good.");
    }

    my $interval = &getChanConfDefault("wingateInterval", 60); # seconds.
    return if (defined $forked{'wingate'});
    return if (time() - $wingaterun <= $interval);
    return unless (scalar(keys %wingateToDo));

    $wingaterun = time();

    &Forker("wingate", sub { &Wingate::Wingates(keys %wingateToDo); } );
    undef @wingateNow;
}

### TODO.
sub wingateWriteFile {
    if (@_) {
	&ScheduleThis(60, "wingateWriteFile");
	return if ($_[0] eq "2");	# defer.
    }

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
}

sub factoidCheck {
    if (@_) {
	&ScheduleThis(720, "factoidCheck");
	return if ($_[0] eq "2");	# defer.
    }

    my @list	= &searchTable("factoids", "factoid_key", "factoid_key", " #DEL#");
    my $stale	= &getChanConfDefault("factoidDeleteDelay", 14) *60*60*24;
    if ($stale < 1) {
	# disable it since it's "illegal".
	return;
    }

    my $time	= time();

    foreach (@list) {
	my $age = &getFactInfo($_, "modified_time");	

	if (!defined $age or $age !~ /^\d+$/) {
	    if (scalar @list > 50) {
		if (!$cache{warnDel}) {
		    &WARN("list is over 50 (".scalar(@list)."... giving it a miss.");
		    $cache{warnDel} = 1;
		    last;
		}
	    }

	    &WARN("del factoid: old cruft (no time): $_");
	    &delFactoid($_);
	    next;
	}

	next unless ($time - $age > $stale);

	my $fix = $_;
	$fix =~ s/ #DEL#$//g;
	my $agestr = &Time2String($time - $age);
	&status("safedel: Removing '$_' for good. [$agestr old]");

	&delFactoid($_);
    }
}

sub dccStatus {
    return unless (scalar keys %{ $dcc{CHAT} });

    if (@_) {
	&ScheduleThis(10, "dccStatus");
	return if ($_[0] eq "2");	# defer.
    }

    my $time = strftime("%H:%M", localtime(time()) );

    my $c;
    foreach (keys %channels) {
	my $c		= $_;
	my $users	= keys %{ $channels{$c}{''} };
	my $chops	= keys %{ $channels{$c}{o}  };
	my $bans	= keys %{ $channels{$c}{b}  };

	my $txt = "[$time] $c: $users members ($chops chops), $bans bans";
	foreach (keys %{ $dcc{'CHAT'} }) {
	    next unless (exists $channels{$c}{''}{lc $_});
	    $conn->privmsg($dcc{'CHAT'}{$_}, $txt);
	}
    }
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

sub mkBackup {
    my($file, $time)	= @_;
    my $backup		= 0;

    if (! -f $file) {
	&VERB("mkB: file '$file' does not exist.",2);
	return;
    }

    my $age	= "New";
    if ( -e "$file~" ) {
 	$backup++	if ((stat $file)[9] - (stat "$file~")[9] > $time);
	my $delta	= time() - (stat "$file~")[9];
	$age		= &Time2String($delta);
    } else {
	$backup++;
    }

    return unless ($backup);

    ### TODO: do internal copying.
    &status("Backup: $file ($age)");
    CORE::system("/bin/cp $file $file~");
}

1;
