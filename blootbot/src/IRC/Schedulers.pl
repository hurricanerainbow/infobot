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
    &freshmeatLoop(2);
    &kernelLoop(2);
    &wingateWriteFile(2);
    &factoidCheck(2);
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
    $sched{$codename}{RUNNING}	= 1;
}

####
#### LET THE FUN BEGIN.
####

sub randomQuote {
    my $interval = &getChanConfDefault("randomQuoteInterval", 60);
    if (@_) {
	&ScheduleThis($interval, "randomQuote");
	return if ($_[0] eq "2");	# defer.
    } else {
	delete $sched{"randomQuote"}{RUNNING};
    }

    my $line = &getRandomLineFromFile($bot_misc_dir. "/blootbot.randtext");
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
    } else {
	delete $sched{"randomFactoid"}{RUNNING};
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
    } else {
	delete $sched{"randomFreshmeat"}{RUNNING};
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
    } else {
	delete $sched{"logLoop"}{RUNNING};
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
	return if ($_[0] eq "2");	# defer.
    } else {
	delete $sched{"seenFlushOld"}{RUNNING};
    }

    # is this global-only?
    return unless (&IsChanConf("seen") > 0);
    return unless (&IsChanConf("seenFlushInterval") > 0);

    # global setting. does not make sense for per-channel.
    my $max_time = &getChanConfDefault("seenMaxDays", 30) *60*60*24;
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

sub newsFlush {
    if (@_) {
	&ScheduleThis(1440, "newsFlush");
	return if ($_[0] eq "2");	# defer.
    } else {
	delete $sched{"newsFlush"}{RUNNING};
    }

    return unless (&IsChanConf("news") > 0);

    my $delete	= 0;
    my $oldest	= time();
    foreach $chan (keys %::news) {
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

	    next unless (time() > $t);
	    # todo: show how old it was.
	    delete $::news{$chan}{$item};
	    &VERB("NEWS: deleted '$item'", 2);
	    $delete++;
	}
    }

    # todo: flush users aswell.
    my $duser	= 0;
    foreach $chan (keys %::newsuser) {
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
    }

#    &VERB("NEWS deleted $delete seen entries.",2);
    &status("NEWS deleted: $delete news entries; $duser user cache.");

    &News::writeNews();
}

sub chanlimitCheck {
    my $interval = &getChanConfDefault("chanlimitcheckInterval", 10);

    if (@_) {
	&ScheduleThis($interval, "chanlimitCheck");
	return if ($_[0] eq "2");
    } else {
	delete $sched{"chanlimitCheck"}{RUNNING};
    }

    foreach $chan ( &ChanConfList("chanlimitcheck") ) {
	next unless (&validChan($chan));

	my $limitplus	= &getChanConfDefault("chanlimitcheckPlus", 5, $chan);
	my $newlimit	= scalar(keys %{$channels{$chan}{''}}) + $limitplus;
	my $limit	= $channels{$chan}{'l'};

	if (defined $limit and scalar keys %{$channels{$chan}{''}} > $limit) {
	    &FIXME("LIMIT: set too low!!! FIXME");
	    ### run NAMES again and flush it.
	}

	next unless (!defined $limit or $limit != $newlimit);

	if (!exists $channels{$chan}{'o'}{$ident}) {
	    &status("ChanLimit: dont have ops on $chan.") unless (exists $cache{warn}{chanlimit}{$chan});
	    $cache{warn}{chanlimit}{$chan} = 1;
	    ### TODO: check chanserv?
	    next;
	}
	delete $cache{warn}{chanlimit}{$chan};

	if (!defined $limit) {
	    &status("ChanLimit: setting for first time or from netsplit, for $chan");
	}

	if (exists $cache{ "chanlimitChange_$chan" }) {
	    my $delta = time() - $cache{ "chanlimitChange_$chan" };
	    if ($delta < $interval*60) {
		&DEBUG("not going to change chanlimit! ($delta<$interval*60)");
		return;
	    }
	}

	&rawout("MODE $chan +l $newlimit");
	$cache{ "chanlimitChange_$chan" } = time();
    }
}

sub netsplitCheck {
    my ($s1,$s2);

    if (@_) {
	&ScheduleThis(30, "netsplitCheck");
	return if ($_[0] eq "2");
    } else {
	delete $sched{"netsplitCheck"}{RUNNING};
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
    my $count	= scalar keys %netsplit;
    foreach (keys %netsplit) {
	if (&IsNickInAnyChan($_)) {
	    &DEBUG("netsplitC: $_ is in some chan; removing from netsplit list.");
	    delete $netsplit{$_};
	    next;
	}
	next unless (time() - $netsplit{$_} > 60*10);

	&DEBUG("netsplitC: $_ didn't come back from netsplit; removing from netsplit list.");
	delete $netsplit{$_};
    }

    if ($count and !scalar keys %netsplit) {
	&DEBUG("ok, netsplit is hopefully gone. reinstating chanlimit check.");
	&chanlimitCheck();
    }
}

sub floodLoop {
    my $delete   = 0;
    my $who;

    if (@_) {
	&ScheduleThis(60, "floodLoop");	# minutes.
	return if ($_[0] eq "2");
    } else {
	delete $sched{"floodLoop"}{RUNNING};
    }

    my $time		= time();
    my $interval	= &getChanConfDefault("floodCycle",60);

    foreach $who (keys %flood) {
	foreach (keys %{$flood{$who}}) {
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
    } else {
	delete $sched{"seenFlush"}{RUNNING};
    }

    my %stats;
    my $nick;
    my $flushed 	= 0;
    $stats{'count_old'} = &countKeys("seen") || 0;
    $stats{'new'}	= 0;
    $stats{'old'}	= 0;

    if ($param{'DBType'} =~ /^mysql|pg|postgres/i) {
	foreach $nick (keys %seencache) {
	    if (0) {
	    #BROKEN#
	    my $retval = &dbReplace("seen", "nick", $nick, (
			"nick" => $seencache{$nick}{'nick'},
			"time" => $seencache{$nick}{'time'},
			"host" => $seencache{$nick}{'host'},
			"channel" => $seencache{$nick}{'chan'},
			"message" => $seencache{$nick}{'msg'},
	    ) );
	    &DEBUG("retval => $retval.");
	    delete $seencache{$nick};
	    $flushed++;

	    next;
	    }
	    ### OLD CODE...

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
	$stats{'new'}*100/($stats{'count_old'} || 1),
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
	&ScheduleThis(240, "leakCheck");
	return if ($_[0] eq "2");
    } else {
	delete $sched{"leakCheck"}{RUNNING};
    }

    # flood.
    foreach $blah1 (keys %flood) {
	foreach $blah2 (keys %{ $flood{$blah1} }) {
	    $count += scalar(keys %{ $flood{$blah1}{$blah2} });
	}
    }
    &DEBUG("leak: hash flood has $count total keys.",2);

    # floodjoin.
    $count = 0;
    foreach $blah1 (keys %floodjoin) {
	foreach $blah2 (keys %{ $floodjoin{$blah1} }) {
	    $count += scalar(keys %{ $floodjoin{$blah1}{$blah2} });
	}
    }
    &DEBUG("leak: hash flood has $count total keys.",2);

    # floodwarn.
    $count = scalar(keys %floodwarn);
    &DEBUG("leak: hash floodwarn has $count total keys.",2);

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
    } else {
	delete $sched{"ignoreCheck"}{RUNNING};
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
    &VERB("ignore: $count items deleted.",2);
}

sub ircCheck {

    if (@_) {
	&ScheduleThis(60, "ircCheck");
	return if ($_[0] eq "2");	# defer.
    } else {
	delete $sched{"ircCheck"}{RUNNING};
    }

    my @array = grep !/^_default$/, keys %chanconf;
    my $iconf = scalar(@array);
    my $inow  = scalar(keys %channels);
    if ($iconf > 2 and $inow * 2 <= $iconf) {
	&FIXME("ircCheck: current channels * 2 <= config channels. FIXME.");
    }

    # chanserv ops.
    foreach ( &ChanConfList("chanServ_ops") ) {
	next if (exists $channels{$chan}{'o'}{$ident});

	&status("ChanServ ==> Requesting ops for $chan. (3)");
	&rawout("PRIVMSG ChanServ :OP $chan $ident");
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
	if (! &IsNickInAnyChan( $param{ircNick} ) ) {
	    &DEBUG("$param{ircNick} not in use... changing!");
	    &nick( $param{ircNick} );
	} else {
	    &WARN("$param{ircNick} is still in use...");
	}
    }

    &joinNextChan();
	# if scalar @joinnext => join more channels
	# else check for chanserv.

    if (grep /^\s*$/, keys %channels) {
	&WARN("ircCheck: we have a NULL chan in hash channels? removing!");
	if (exists $channels{''}) {
	    &DEBUG("ircCheck: ok it existed!");
	} else {
	    &DEBUG("ircCheck: this hsould never happen!");
	}

	delete $channels{''};
    }

    &DEBUG("ircstats...");
    &DEBUG("  pubsleep: $pubsleep");
    &DEBUG("  msgsleep: $msgsleep");
    &DEBUG("  notsleep: $notsleep");

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
	&ScheduleThis(240, "miscCheck");
	return if ($_[0] eq "2");	# defer.
    } else {
	delete $sched{"miscCheck"}{RUNNING};
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
    &mkBackup( $bot_misc_dir."/blootbot.chan", 60*60*24*3);
    &mkBackup( $bot_misc_dir."/blootbot.users", 60*60*24*3);
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
    } else {
	delete $sched{"miscCheck2"}{RUNNING};
    }

    &DEBUG("miscCheck2: Doing debian checking...");

    # debian check.
    opendir(DEBIAN, "$bot_base_dir/debian");
    foreach ( grep /gz$/, readdir(DEBIAN) ) {
	my $exit = CORE::system("gzip -t $bot_base_dir/debian/$_");
	next unless ($exit);

	&status("debian: unlinking file => $_");
	unlink "$bot_base_dir/debian/$_";
    }
    closedir DEBIAN;

    # compress logs that should have been compressed.
    # todo: use strftime?
    my ($day,$month,$year) = (localtime(time()))[3,4,5];
    my $date = sprintf("%04d%02d%02d",$year+1900,$month+1,$day);

    opendir(DIR,"$bot_base_dir/log");
    while (my $f = readdir(DIR)) {
	next unless ( -f "$bot_base_dir/log/$f");
	next if ($f =~ /gz|bz2/);
	next unless ($f =~ /(\d{8})/);
	next if ($date eq $1);

	&compress("$bot_base_dir/log/$f");
    }
    closedir DIR;
}

sub shmFlush {
    return if ($$ != $::bot_pid); # fork protection.

    if (@_) {
	&ScheduleThis(5, "shmFlush");
	return if ($_[0] eq "2");
    } else {
	delete $sched{"shmFlush"}{RUNNING};
    }

    my $time;
    my $shmmsg = &shmRead($shm);
    $shmmsg =~ s/\0//g;         # remove padded \0's.
    if ($shmmsg =~ s/^(\d+): //) {
	$time	= $1;
    }

    foreach (split '\|\|', $shmmsg) {
	next if (/^$/);
	&VERB("shm: Processing '$_'.",2);

	if (/^DCC SEND (\S+) (\S+)$/) {
	    my ($nick,$file) = ($1,$2);
	    if (exists $dcc{'SEND'}{$who}) {
		&msg($nick, "DCC already active.");
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

    if (@_) {
	&ScheduleThis(30, "getNickInUse");
	return if ($_[0] eq "2");	# defer.
    } else {
	delete $sched{"getNickInUse"}{RUNNING};
    }

    &status("Trying to get my nick back.");
    &nick( $param{'ircNick'} );
}

sub uptimeLoop {
    return unless &IsChanConf("uptime");

    if (@_) {
	&ScheduleThis(60, "uptimeLoop");
	return if ($_[0] eq "2");	# defer.
    } else {
	delete $sched{"uptimeLoop"}{RUNNING};
    }

    &uptimeWriteFile();
}

sub slashdotLoop {

    if (@_) {
	&ScheduleThis(60, "slashdotLoop");
	return if ($_[0] eq "2");
    } else {
	delete $sched{"slashdotLoop"}{RUNNING};
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

sub freshmeatLoop {
    if (@_) {
	&ScheduleThis(60, "freshmeatLoop");
	return if ($_[0] eq "2");
    } else {
	delete $sched{"freshmeatLoop"}{RUNNING};
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
    } else {
	delete $sched{"kernelLoop"}{RUNNING};
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
    } else {
	delete $sched{"wingateWriteFile"}{RUNNING};
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
	&ScheduleThis(1440, "factoidCheck");
	return if ($_[0] eq "2");	# defer.
    } else {
	delete $sched{"factoidCheck"}{RUNNING};
    }

    my @list	= &searchTable("factoids", "factoid_key", "factoid_key", " #DEL#");
    my $stale	= &getChanConfDefault("factoidDeleteDelay", 30) *60*60*24;
    my $time	= time();

    foreach (@list) {
	my $age = &getFactInfo($_, "modified_time");	
	if (!defined $age or $age !~ /^\d+$/) {
	    &WARN("age == NULL or not numeric.");
	    next;
	}

	next unless ($time - $age > $stale);

	my $fix = $_;
	$fix =~ s/ #DEL#$//g;
	&DEBUG("safedel: Removing $fix ($_) for good.");

	&delFactoid($_);
    }

}

sub dccStatus {
    return unless (scalar keys %{ $dcc{CHAT} });

    if (@_) {
	&ScheduleThis(10, "dccStatus");
	return if ($_[0] eq "2");	# defer.
    } else {
	delete $sched{"dccStatus"}{RUNNING};
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

sub getChanConfDefault {
    my($what, $default, $chan) = @_;

    if (exists $param{$what}) {
	if (!exists $cache{config}{$what}) {
	    &status("conf: backward-compat: found param{$what} ($param{$what}) instead.");
	    $cache{config}{$what} = 1;
	}

	return $param{$what};
    }

    my $val = &getChanConf($what, $chan);
    if (defined $val) {
	return $val;
    }

    $param{$what}	= $default;
    &status("conf: auto-setting param{$what} = $default");
    $cache{config}{$what} = 1;

    return $default;
}

sub mkBackup {
    my($file, $time) = @_;
    my $backup	= 0;

    if (! -f $file) {
	&WARN("mkB: file $file don't exist.");
	return;
    }

    if ( -e "$file~" ) {
 	$backup++ if ((stat $file)[9] - (stat "$file~")[9] > $time);
    } else {
	$backup++;
    }
    return unless ($backup);

    ### TODO: do internal copying.
    &status("Backup: $file to $file~");
    CORE::system("/bin/cp $file $file~");
}

1;
