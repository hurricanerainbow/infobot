#
# IrcHooks.pl: IRC Hooks stuff.
#      Author: dms
#     Version: 20000126
#        NOTE: Based on code by Kevin Lenzo & Patrick Cole  (c) 1997
#

if (&IsParam("useStrict")) { use strict; }

# GENERIC. TO COPY.
sub on_generic {
    my ($self, $event) = @_;
    my $nick = $event->nick();
    my $chan = ($event->to)[0];

    &DEBUG("on_generic: nick => '$nick'.");
    &DEBUG("on_generic: chan => '$chan'.");

    foreach ($event->args) {
	&DEBUG("on_generic: args => '$_'.");
    }
}

sub on_action {
    my ($self, $event) = @_;
    my ($nick, @args) = ($event->nick, $event->args);
    my $chan = ($event->to)[0];

    shift @args;

    if ($chan eq $ident) {
	&status("* [$nick] @args");
    } else {
	&status("* $nick/$chan @args");
    }
}

sub on_chat {
    my ($self, $event) = @_;
    my $msg  = ($event->args)[0];
    my $sock = ($event->to)[0];
    my $nick = lc $event->nick();

    if (!exists $nuh{$nick}) {
	&DEBUG("chat: nuh{$nick} doesn't exist; trying WHOIS .");
	$self->whois($nick);
	return;
    }

    ### set vars that would have been set in hookMsg.
    $userHandle		= "";	# reset.
    $who		= lc $nick;
    $message		= $msg;
    $orig{who}		= $nick;
    $orig{message}	= $msg;
    $nuh		= $nuh{$who};
    $uh			= (split /\!/, $nuh)[1];
    $h			= (split /\@/, $uh)[1];
    $addressed		= 1;
    $msgType		= 'chat';

    if (!exists $dcc{'CHATvrfy'}{$nick}) {
	$userHandle	= &verifyUser($who, $nuh);
	my $crypto	= $users{$userHandle}{PASS};
	my $success	= 0;

	if ($userHandle eq "_default") {
	    &WARN("DCC CHAT: _default/guest not allowed.");
	    return;
	}

	### TODO: prevent users without CRYPT chatting.
	if (!defined $crypto) {
	    &DEBUG("todo: dcc close chat");
	    &msg($who, "nope, no guest logins allowed...");
	    return;
	}

	if (&ckpasswd($msg, $crypto)) {
	    # stolen from eggdrop.
	    $self->privmsg($sock, "Connected to $ident");
	    $self->privmsg($sock, "Commands start with '.' (like '.quit' or '.help')");
	    $self->privmsg($sock, "Everything else goes out to the party line.");

	    &dccStatus(2) unless (exists $sched{"dccStatus"}{RUNNING});

	    $success++;

	} else {
	    &status("DCC CHAT: incorrect pass; closing connection.");
	    &DEBUG("chat: sock => '$sock'.");
###	    $sock->close();
	    delete $dcc{'CHAT'}{$nick};
	    &DEBUG("chat: after closing sock. FIXME");
	    ### BUG: close seizes bot. why?
	}

	if ($success) {
	    &status("DCC CHAT: user $nick is here!");
	    &DCCBroadcast("*** $nick ($uh) joined the party line.");

	    $dcc{'CHATvrfy'}{$nick} = $userHandle;

	    return if ($userHandle eq "_default");

	    &dccsay($nick,"Flags: $users{$userHandle}{FLAGS}");
	}

	return;
    }

    &status("$b_red=$b_cyan$who$b_red=$ob $message");

    if ($message =~ s/^\.//) {	# dcc chat commands.
	### TODO: make use of &Forker(); here?
	&loadMyModule( $myModules{'ircdcc'} );

	&DCCBroadcast("#$who# $message","m");

	my $retval	= &userDCC();
	return unless (defined $retval);
	return if ($retval eq $noreply);

	$conn->privmsg($dcc{'CHAT'}{$who}, "Invalid command.");

    } else {			# dcc chat arena.

	foreach (keys %{ $dcc{'CHAT'} }) {
	    $conn->privmsg($dcc{'CHAT'}{$_}, "<$who> $orig{message}");
	}
    }

    return 'DCC CHAT MESSAGE';
}

sub on_endofmotd {
    my ($self) = @_;

    # update IRCStats.
    $ident	||= $param{'ircNick'};	# hack.
    $ircstats{'ConnectTime'}	= time();
    $ircstats{'ConnectCount'}++;
    $ircstats{'OffTime'}	+= time() - $ircstats{'DisconnectTime'}
			if (defined $ircstats{'DisconnectTime'});

    # first time run.
    if (!exists $users{_default}) {
	&status("!!! First time run... adding _default user.");
	$users{_default}{FLAGS}	= "mrt";
	$users{_default}{HOSTS}{"*!*@*"} = 1;
    }

    if (scalar keys %users < 2) {
	&status("!"x40);
	&status("!!! Ok.  Now type '/msg $ident PASS <pass>' to get master access through DCC CHAT.");
	&status("!"x40);
    }
    # end of first time run.

    if (&IsChanConf("wingate")) {
	my $file = "$bot_base_dir/$param{'ircUser'}.wingate";
	open(IN, $file);
	while (<IN>) {
	    chop;
	    next unless (/^(\S+)\*$/);
	    push(@wingateBad, $_);
	}
	close IN;
    }

    if ($firsttime) {
	&ScheduleThis(1, \&setupSchedulers);
	$firsttime = 0;
    }

    if (&IsParam("ircUMode")) {
	&VERB("Attempting change of user modes to $param{'ircUMode'}.", 2);
	if ($param{'ircUMode'} !~ /^[-+]/) {
	    &WARN("ircUMode had no +- prefix; adding +");
	    $param{'ircUMode'} = "+".$param{'ircUMode'};
	}

	&rawout("MODE $ident $param{'ircUMode'}");
    }

    &status("End of motd. Now lets join some channels...");
    if (!scalar @joinchan) {
	&WARN("joinchan array is empty!!!");
	@joinchan = &getJoinChans(1);
    }

    # ok, we're free to do whatever we want now. go for it!
    $running = 1;

    # unfortunately, Net::IRC does not implement this :(
    # invalid command... what is it?
#    &rawout("NOTIFY $ident");
#    &DEBUG("adding self to NOTIFY list.");

    &joinNextChan();
}

sub on_endofwho {
    my ($self, $event) = @_;
#    &DEBUG("endofwho: chan => $chan");
    $chan	||= ($event->args)[1];
#    &DEBUG("endofwho: chan => $chan");

    if (exists $cache{countryStats}) {
	&do_countrystats();
    }
}

sub on_dcc {
    my ($self, $event) = @_;
    my $type = uc( ($event->args)[1] );
    my $nick = lc $event->nick();

    # pity Net::IRC doesn't store nuh. Here's a hack :)
    if (!exists $nuh{lc $nick}) {
	$self->whois($nick);
	$nuh{$nick}	= "GETTING-NOW";	# trying.
    }
    $type ||= "???";

    if ($type eq 'SEND') {	# GET for us.
	# incoming DCC SEND. we're receiving a file.
	my $get = ($event->args)[2];
	open(DCCGET,">$get");

	$self->new_get($nick,
		($event->args)[2],
		($event->args)[3],
		($event->args)[4],
		($event->args)[5],
		\*DCCGET
	);
    } elsif ($type eq 'GET') {	# SEND for us?
	&status("DCC: Initializing SEND for $nick.");
	$self->new_send($event->args);

    } elsif ($type eq 'CHAT') {
	&status("DCC: Initializing CHAT for $nick.");
	$self->new_chat($event);

    } else {
	&WARN("${b_green}DCC $type$ob (1)");
    }
}

sub on_dcc_close {
    my ($self, $event) = @_;
    my $nick = $event->nick();
    my $sock = ($event->to)[0];

    # DCC CHAT close on fork exit workaround.
    if ($bot_pid != $$) {
	&WARN("run-away fork; exiting.");
	&delForked($forker);
    }

    if (exists $dcc{'SEND'}{$nick} and -f "$param{tempDir}/$nick.txt") {
	&status("${b_green}DCC SEND$ob close from $b_cyan$nick$ob");

	&status("dcc_close: purging $nick.txt from Debian.pl");
	unlink "$param{tempDir}/$nick.txt";

	delete $dcc{'SEND'}{$nick};
    } elsif (exists $dcc{'CHAT'}{$nick} and $dcc{'CHAT'}{$nick} eq $sock) {
	&status("${b_green}DCC CHAT$ob close from $b_cyan$nick$ob");
	delete $dcc{'CHAT'}{$nick};
	delete $dcc{'CHATvrfy'}{$nick};
    } else {
	&status("${b_green}DCC$ob UNKNOWN close from $b_cyan$nick$ob (2)");
    }
}

sub on_dcc_open {
    my ($self, $event) = @_;
    my $type = uc( ($event->args)[0] );
    my $nick = lc $event->nick();
    my $sock = ($event->to)[0];

    $msgType = 'chat';
    $type ||= "???";
    ### BUG: who is set to bot's nick?

    # lets do it.
    if ($type eq 'SEND') {
	&status("${b_green}DCC lGET$ob established with $b_cyan$nick$ob");

    } elsif ($type eq 'CHAT') {
	# very cheap hack.
	### TODO: run ScheduleThis inside on_dcc_open_chat recursively
	###	1,3,5,10 seconds then fail.
	if ($nuh{$nick} eq "GETTING-NOW") {
	    &ScheduleThis(3/60, "on_dcc_open_chat", $nick, $sock);
	} else {
	    on_dcc_open_chat(undef, $nick, $sock);
	}

    } elsif ($type eq 'SEND') {
	&DEBUG("Starting DCC receive.");
	foreach ($event->args) {
	    &DEBUG("  => '$_'.");
	}

    } else {
	&WARN("${b_green}DCC $type$ob (3)");
    }
}

# really custom sub to get NUH since Net::IRC doesn't appear to support
# it.
sub on_dcc_open_chat {
    my(undef, $nick, $sock) = @_;

    if ($nuh{$nick} eq "GETTING-NOW") {
	&DEBUG("getting nuh for $nick failed. FIXME.");
	return;
    }

    &status("${b_green}DCC CHAT$ob established with $b_cyan$nick$ob $b_yellow($ob$nuh{$nick}$b_yellow)$ob");

    &verifyUser($nick, $nuh{lc $nick});

    if (!exists $users{$userHandle}{HOSTS}) {
	&pSReply("you have no hosts defined in my user file; rejecting.");
	$sock->close();
	return;
    }

    my $crypto	= $users{$userHandle}{PASS};
    $dcc{'CHAT'}{$nick} = $sock;

    # todo: don't make DCC CHAT established in the first place.
    if ($userHandle eq "_default") {
	&dccsay($nick, "_default/guest not allowed");
	$sock->close();
	return;
    }

    if (defined $crypto) {
	&status("DCC CHAT: going to use ".$nick."'s crypt.");
	&dccsay($nick,"Enter your password.");
    } else {
#	&dccsay($nick,"Welcome to blootbot DCC CHAT interface, $userHandle.");
    }
}

sub on_disconnect {
    my ($self, $event) = @_;
    my $from = $event->from();
    my $what = ($event->args)[0];

    &status("disconnect from $from ($what).");
    $ircstats{'DisconnectTime'}		= time();
    $ircstats{'DisconnectReason'}	= $what;
    $ircstats{'DisconnectCount'}++;
    $ircstats{'TotalTime'}	+= time() - $ircstats{'ConnectTime'}
					if ($ircstats{'ConnectTime'});

    # clear any variables on reconnection.
    $nickserv = 0;

    &DEBUG("on_disconnect: 1");
    &clearIRCVars();
    &DEBUG("on_disconnect: 2");

    if (!defined $self) {
	&WARN("on_disconnect: self is undefined! WTF");
	&DEBUG("running function irc... lets hope this works.");
	&irc();
	return;
    }

    if (!$self->connect()) {
	&DEBUG("on_disconnect: 3");
	&WARN("not connected? help me. gonna call ircCheck() in 60s");
	&clearIRCVars();
	&ScheduleThis(1, "ircCheck");
    }
}

sub on_endofnames {
    my ($self, $event) = @_;
    my $chan = ($event->args)[1];

    # sync time should be done in on_endofwho like in BitchX
    if (exists $cache{jointime}{$chan}) {
	my $delta_time = sprintf("%.03f", &timedelta($cache{jointime}{$chan}) );
	$delta_time    = 0	if ($delta_time <= 0);
	if ($delta_time > 100) {
	    &WARN("endofnames: delta_time > 100 ($delta_time)");
	}

	&status("$b_blue$chan$ob: sync in ${delta_time}s.");
    }

    &rawout("MODE $chan");

    my $txt;
    my @array;
    foreach ("o","v","") {
	my $count = scalar(keys %{ $channels{$chan}{$_} });
	next unless ($count);

	$txt = "total" if ($_ eq "");
	$txt = "voice" if ($_ eq "v");
	$txt = "ops"   if ($_ eq "o");

	push(@array, "$count $txt");
    }
    my $chanstats = join(' || ', @array);
    &status("$b_blue$chan$ob: [$chanstats]");

    &chanServCheck($chan);
    # schedule used to solve ircu (OPN) "target too fast" problems.
    $conn->schedule(5, sub { &joinNextChan(); } );
}

sub on_init {
    my ($self, $event) = @_;
    my (@args) = ($event->args);
    shift @args;

    &status("@args");
}

sub on_invite {
    my ($self, $event) = @_;
    my $chan = lc( ($event->args)[0] );
    my $nick = $event->nick;

    if ($nick =~ /^\Q$ident\E$/) {
	&DEBUG("on_invite: self invite.");
	return;
    }

    ### TODO: join key.
    if (exists $chanconf{$chan}) {
	# it's still buggy :/
	if (&validChan($chan)) {
	    &msg($who, "i'm already in \002$chan\002.");
#	    return;
	}

	&status("invited to $b_blue$chan$ob by $b_cyan$nick$ob");
	&joinchan($chan);
    }
}

sub on_join {
    my ($self, $event)	= @_;
    my ($user,$host)	= split(/\@/, $event->userhost);
    $chan		= lc( ($event->to)[0] ); # CASING!!!!
    $who		= $event->nick();
    $msgType		= "public";
    my $i		= scalar(keys %{ $channels{$chan} });
    my $j		= $cache{maxpeeps}{$chan} || 0;

    $chanstats{$chan}{'Join'}++;
    $userstats{lc $who}{'Join'} = time() if (&IsChanConf("seenStats"));
    $cache{maxpeeps}{$chan}	= $i if ($i > $j);

    &joinfloodCheck($who, $chan, $event->userhost);

    # netjoin detection.
    my $netsplit = 0;
    if (exists $netsplit{lc $who}) {
	delete $netsplit{lc $who};
	$netsplit = 1;

	if (!scalar keys %netsplit) {
	    &DEBUG("on_join: netsplit hash is now empty!");
	    undef %netsplitservers;
	    &netsplitCheck();	# any point in running this?
	    &chanlimitCheck();
	}
    }

    if ($netsplit and !exists $cache{netsplit}) {
	&VERB("on_join: ok.... re-running chanlimitCheck in 60.",2);
	$conn->schedule(60, sub {
		&chanlimitCheck();
		delete $cache{netsplit};
	} );

	$cache{netsplit} = time();
    }

    # how to tell if there's a netjoin???

    my $netsplitstr = "";
    $netsplitstr = " $b_yellow\[${ob}NETSPLIT VICTIM$b_yellow]$ob" if ($netsplit);
    &status(">>> join/$b_blue$chan$ob $b_cyan$who$ob $b_yellow($ob$user\@$host$b_yellow)$ob$netsplitstr");

    $channels{$chan}{''}{$who}++;
    $nuh	  = $who."!".$user."\@".$host;
    $nuh{lc $who} = $nuh unless (exists $nuh{lc $who});

    ### on-join bans.
    my @bans;
    push(@bans, keys %{ $bans{$chan} }) if (exists $bans{$chan});
    push(@bans, keys %{ $bans{"*"} })   if (exists $bans{"*"});

    foreach (@bans) {
	my $ban	= $_;
	s/\?/./g;
	s/\*/\\S*/g;
	my $mask	= $_;
	next unless ($nuh =~ /^$mask$/i);

	### TODO: check $channels{$chan}{'b'} if ban already exists.
	foreach (keys %{ $channels{$chan}{'b'} }) {
	    &DEBUG(" bans_on_chan($chan) => $_");
	}

	my $reason = "no reason";
	foreach ($chan, "*") {
	    next unless (exists $bans{$_});
	    next unless (exists $bans{$_}{$ban});

	    my @array	= @{ $bans{$_}{$ban} };

	    $reason	= $array[4] if ($array[4]);
	    last;
	}

	&ban($ban, $chan);
	&kick($who, $chan, $reason);

	last;
    }

    # no need to go further.
    return if ($netsplit);

    # who == bot.
    if ($who eq $ident or $who =~ /^$ident$/i) {
	if (defined( my $whojoin = $cache{join}{$chan} )) {
	    &msg($chan, "Okay, I'm here. (courtesy of $whojoin)");
	    delete $cache{join}{$chan};
	    &joinNextChan();	# hack.
	}

	### TODO: move this to &joinchan()?
	$cache{jointime}{$chan} = &timeget();
	rawout("WHO $chan");

	return;
    }

    ### ROOTWARN:
    &rootWarn($who,$user,$host,$chan) if (
		&IsChanConf("rootWarn") &&
		$user =~ /^r(oo|ew|00)t$/i
    );

    ### NEWS:
    if (&IsChanConf("news") && &IsChanConf("newsKeepRead")) {
	if (!&loadMyModule("news")) {	# just in case.
	    &DEBUG("could not load news.");
	} else {
	    &News::latest($chan);
	}
    }

    ### chanlimit check.
#    &chanLimitVerify($chan);

    ### wingate:
    &wingateCheck();
}

sub on_kick {
    my ($self, $event) = @_;
    my ($chan,$reason) = $event->args;
    my $kicker	= $event->nick;
    my $kickee	= ($event->to)[0];
    my $uh	= $event->userhost();

    &status(">>> kick/$b_blue$chan$ob [$b$kickee!$uh$ob] by $b_cyan$kicker$ob $b_yellow($ob$reason$b_yellow)$ob");

    $chan = lc $chan;	# forgot about this, found by xsdg, 20001229.
    $chanstats{$chan}{'Kick'}++;

    if ($kickee eq $ident) {
	&clearChanVars($chan);

	&status("SELF attempting to rejoin lost channel $chan");
	&joinchan($chan);
    } else {
	&delUserInfo($kickee,$chan);
    }
}

sub on_mode {
    my ($self, $event)	= @_;
    my ($user, $host)	= split(/\@/, $event->userhost);
    my @args	= $event->args();
    my $nick	= $event->nick();
    $chan	= ($event->to)[0];

    $args[0] =~ s/\s$//;

    if ($nick eq $chan) {	# UMODE
	&status(">>> mode $b_yellow\[$ob$b@args$b_yellow\]$ob by $b_cyan$nick$ob");
    } else {			# MODE
	&status(">>> mode/$b_blue$chan$ob $b_yellow\[$ob$b@args$b_yellow\]$ob by $b_cyan$nick$ob");
	&hookMode($nick, @args);
    }
}

sub on_modeis {
    my ($self, $event) = @_;
    my ($myself, undef,@args) = $event->args();
    my $nick	= $event->nick();
    $chan	= ($event->args())[1];

    &hookMode($nick, @args);
}

sub on_msg {
    my ($self, $event) = @_;
    my $nick = $event->nick;
    my $msg  = ($event->args)[0];

    ($user,$host) = split(/\@/, $event->userhost);
    $uh		= $event->userhost();
    $nuh	= $nick."!".$uh;
    $msgtime	= time();
    $h		= $host;

    if ($nick eq $ident) { # hopefully ourselves.
	if ($msg eq "TEST") {
	    &status("IRCTEST: Yes, we're alive.");
	    delete $cache{connect};
	    return;
	}
    }

    &hookMsg('private', undef, $nick, $msg);
    $who	= "";
    $chan	= "";
    $msgType	= "";
}

sub on_names {
    my ($self, $event) = @_;
    my @args = $event->args;
    my $chan = lc $args[2];		# CASING, the last of them!

    foreach (split / /, @args[3..$#args]) {
	$channels{$chan}{'o'}{$_}++	if s/\@//;
	$channels{$chan}{'v'}{$_}++	if s/\+//;
	$channels{$chan}{''}{$_}++;
    }
}

sub on_nick {
    my ($self, $event) = @_;
    my $nick = $event->nick();
    my $newnick = ($event->args)[0];

    if (exists $netsplit{lc $newnick}) {
	&status("Netsplit: $newnick/$nick came back from netsplit and changed to original nick! removing from hash.");
	delete $netsplit{lc $newnick};
	&netsplitCheck() if (time() != $sched{netsplitCheck}{TIME});
    }

    my ($chan,$mode);
    foreach $chan (keys %channels) {
	foreach $mode (keys %{ $channels{$chan} }) {
	    next unless (exists $channels{$chan}{$mode}{$nick});

	    $channels{$chan}{$mode}{$newnick} = $channels{$chan}{$mode}{$nick};
	}
    }
    # todo: do %flood* aswell.

    &delUserInfo($nick, keys %channels);
    $nuh{lc $newnick} = $nuh{lc $nick};
    delete $nuh{lc $nick};

    if ($nick eq $ident) {
	&status(">>> I materialized into $b_green$newnick$ob from $nick");
	$ident	= $newnick;
    } else {
	&status(">>> $b_cyan$nick$ob materializes into $b_green$newnick$ob");

	if ($nick =~ /^\Q$param{'ircNick'}\E$/i) {
	    &getNickInUse();
	}
    }
}

sub on_nick_taken {
    my ($self)	= @_;
    my $nick	= $self->nick;
    my $newnick = $nick."-";

    &status("nick taken ($nick); preparing nick change.");

    $self->whois($nick);
    $conn->schedule(5, sub {
	&status("nick taken; changing to temporary nick ($nick -> $newnick).");
	&nick($newnick);
    } );
}

sub on_notice {
    my ($self, $event) = @_;
    my $nick = $event->nick();
    my $chan = ($event->to)[0];
    my $args = ($event->args)[0];

    if ($nick =~ /^NickServ$/i) {		# nickserv.
	&status("NickServ: <== '$args'");

	my $check	= 0;
	$check++	if ($args =~ /^This nickname is registered/i);
	$check++	if ($args =~ /nickname.*owned/i);

	if ($check) {
	    &status("nickserv told us to register; doing it.");

	    if (&IsParam("nickServ_pass")) {
		&status("NickServ: ==> Identifying.");
		&rawout("PRIVMSG NickServ :IDENTIFY $param{'nickServ_pass'}");
		return;
	    } else {
		&status("We can't tell nickserv a passwd ;(");
	    }
	}

	# password accepted.
	if ($args =~ /^Password a/i) {
	    my $done	= 0;

	    foreach ( &ChanConfList("chanServ_ops") ) {
		next unless &chanServCheck($_);
		next if ($done);
		&DEBUG("nickserv activated or restarted; doing chanserv check.");
		$done++;
	    }

	    $nickserv++;
	}
    } elsif ($nick =~ /^ChanServ$/i) {		# chanserv.
	&status("ChanServ: <== '$args'.");

    } else {
	if ($chan =~ /^$mask{chan}$/) {	# channel notice.
	    &status("-$nick/$chan- $args");
	} else {
	    $server = $nick unless (defined $server);
	    &status("-$nick- $args");	# private or server notice.
	}
    }
}

sub on_other {
    my ($self, $event) = @_;
    my $chan = ($event->to)[0];
    my $nick = $event->nick;

    &status("!!! other called.");
    &status("!!! $event->args");
}

sub on_part {
    my ($self, $event) = @_;
    $chan	= lc( ($event->to)[0] );	# CASING!!!
    my $nick	= $event->nick;
    my $userhost = $event->userhost;
    $who	= $nick;
    $msgType	= "public";

    if (0 and !exists $channels{$chan}) {
	&DEBUG("on_part: found out we're on $chan!");
	$channels{$chan} = 1;
    }

    if (exists $floodjoin{$chan}{$nick}{Time}) {
	delete $floodjoin{$chan}{$nick};
    }

    $chanstats{$chan}{'Part'}++;
    &delUserInfo($nick,$chan);
    if ($nick eq $ident) {
	&DEBUG("on_part: ok, I left $chan... clearChanVars...");
	&clearChanVars($chan);
    }

    if (!&IsNickInAnyChan($nick) and &IsChanConf("seenStats")) {
	delete $userstats{lc $nick};
    }

    &status(">>> part/$b_blue$chan$ob $b_cyan$nick$ob $b_yellow($ob$userhost$b_yellow)$ob");
}

sub on_ping {
    my ($self, $event) = @_;
    my $nick = $event->nick;

    $self->ctcp_reply($nick, join(' ', ($event->args)));
    &status(">>> ${b_green}CTCP PING$ob request from $b_cyan$nick$ob received.");
}

sub on_ping_reply {
    my ($self, $event) = @_;
    my $nick	= $event->nick;
    my $t	= ($event->args)[1];
    if (!defined $t) {
	&WARN("on_ping_reply: t == undefined.");
	return;
    }

    my $lag = time() - $t;

    &status(">>> ${b_green}CTCP PING$ob reply from $b_cyan$nick$ob: $lag sec.");
}

sub on_public {
    my ($self, $event) = @_;
    my $msg 	= ($event->args)[0];
    $chan	= lc( ($event->to)[0] );	# CASING.
    my $nick	= $event->nick;
    $who	= $nick;
    $uh		= $event->userhost();
    $nuh	= $nick."!".$uh;
    $msgType	= "public";
    # todo: move this out of hookMsg to here?
    ($user,$host) = split(/\@/, $uh);
    $h		= $host;

    # rare case should this happen - catch it just in case.
    if ($bot_pid != $$) {
	&ERROR("run-away fork; exiting.");
	&delForked($forker);
    }

    $msgtime		= time();
    $lastWho{$chan}	= $nick;
    ### TODO: use $nick or lc $nick?
    if (&IsChanConf("seenStats")) {
	$userstats{lc $nick}{'Count'}++;
	$userstats{lc $nick}{'Time'} = time();
    }

    # would this slow things down?
    if ($_ = &getChanConf("ircTextCounters")) {
	my $time = time();

	foreach (split /[\s]+/) {
	    my $x = $_;

	    # either full word or ends with a space, etc...
	    next unless ($msg =~ /^\Q$x\E[\$\s!.]/i);

	    &VERB("textcounters: $x matched for $who",2);
	    my $c = $chan || "PRIVATE";

	    my ($v,$t) = &dbGet("stats", "counter,time",
			"nick=". &dbQuote($who)
			." AND type=".&dbQuote($x)
			." AND channel=".&dbQuote($c)
	    );
	    $v++;

	    # don't allow ppl to cheat the stats :-)
	    next unless ($time - $t > 10);

	    my %hash = (
		nick	=> $who,
		type	=> $x,
		channel => $c,

		time	=> $time,
		counter => $v,
	    );
		

	    &dbReplace("stats", "nick", %hash);
	    # does not work, atleast with old mysql!!! :(
#	    &dbReplace("stats", (nick => $who, type => $x, -counter => "counter+1") );
	}
    }

    &hookMsg('public', $chan, $nick, $msg);
    $chanstats{$chan}{'PublicMsg'}++;
    $who	= "";
    $chan	= "";
    $msgType	= "";
}

sub on_quit {
    my ($self, $event) = @_;
    my $nick	= $event->nick();
    my $reason	= ($event->args)[0];

    # hack for ICC.
    $msgType	= "public";
    $who	= $nick;
###    $chan	= $reason;	# no.

    my $count	= 0;
    foreach (grep !/^_default$/, keys %channels) {
	# fixes inconsistent chanstats bug #1.
	if (!&IsNickInChan($nick,$_)) {
	    $count++;
	    next;
	}
	$chanstats{$_}{'SignOff'}++;
    }

    if ($count == scalar keys %channels) {
	&DEBUG("on_quit: nick $nick was not found in any chan.");
    }

    # should fix chanstats inconsistencies bug #2.
    if ($reason =~ /^($mask{host})\s($mask{host})$/) {	# netsplit.
	$reason = "NETSPLIT: $1 <=> $2";

	# chanlimit code.
	foreach $chan ( &getNickInChans($nick) ) {
	    next unless ( &IsChanConf("chanlimitcheck") );
	    next unless ( exists $channels{$_}{'l'} );

	    &DEBUG("on_quit: netsplit detected on $_; disabling chan limit.");
	    &rawout("MODE $_ -l");
	}

	$netsplit{lc $nick} = time();
	if (!exists $netsplitservers{$1}{$2}) {
	    &status("netsplit detected between $1 and $2 at [".scalar(localtime)."]");
	    $netsplitservers{$1}{$2} = time();
	}
    }

    my $chans = join(' ', &getNickInChans($nick) );
    &status(">>> $b_cyan$nick$ob has signed off IRC $b_red($ob$reason$b_red)$ob [$chans]");
    if ($nick =~ /^\Q$ident\E$/) {
	&ERROR("^^^ THIS SHOULD NEVER HAPPEN (10).");
    }

    ###
    ### ok... lets clear out the cache
    ###
    &delUserInfo($nick, keys %channels);
    if (exists $nuh{lc $nick}) {
	delete $nuh{lc $nick};
    } else {
	# well.. it's good but weird that this has happened - lets just
	# be quiet about it.
    }
    delete $userstats{lc $nick} if (&IsChanConf("seenStats"));
    delete $chanstats{lc $nick};
    ###

    # does this work?
    if ($nick !~ /^\Q$ident\E$/ and $nick =~ /^\Q$param{'ircNick'}\E$/i) {
	&status("nickchange: own nickname became free; changing.");
	&nick($param{'ircNick'});
    }
}

sub on_targettoofast {
    my ($self, $event) = @_;
    my $nick = $event->nick();
    my($me,$chan,$why) = $event->args();

    ### TODO: incomplete.
    if ($why =~ /.* wait (\d+) second/) {
	my $sleep	= $1;
	my $max		= 10;

	if ($sleep > $max) {
	    &status("targettoofast: going to sleep for $max ($sleep)...");
	    $sleep = $max;
	} else {
	    &status("targettoofast: going to sleep for $sleep");
	}

	my $delta = time() - ($cache{sleepTime} || 0);
	if ($delta > $max+2) {
	    sleep $sleep;
	    $cache{sleepTime} = time();
	}

	return;
    }

    if (!exists $cache{TargetTooFast}) {
	&DEBUG("on_ttf: failed: $why");
	$cache{TargetTooFast}++;
    }
}

sub on_topic {
    my ($self, $event) = @_;

    if (scalar($event->args) == 1) {	# change.
	my $topic = ($event->args)[0];
	my $chan  = ($event->to)[0];
	my $nick  = $event->nick();

	###
	# WARNING:
	#	race condition here. To fix, change '1' to '0'.
	#	This will keep track of topics set by bot only.
	###
	# UPDATE:
	#	this may be fixed at a later date with topic queueing.
	###

	$topic{$chan}{'Current'} = $topic if (1);
	$chanstats{$chan}{'Topic'}++;

	&status(">>> topic/$b_blue$chan$ob by $b_cyan$nick$ob -> $topic");
    } else {						# join.
	my ($nick, $chan, $topic) = $event->args;
	if (&IsChanConf("topic")) {
	    $topic{$chan}{'Current'}	= $topic;
	    &topicAddHistory($chan,$topic);
	}

	$topic = &fixString($topic, 1);
	&status(">>> topic/$b_blue$chan$ob is $topic");
    }
}

sub on_topicinfo {
    my ($self, $event) = @_;
    my ($myself,$chan,$setby,$time) = $event->args();

    my $timestr;
    if (time() - $time > 60*60*24) {
	$timestr	= "at ". localtime $time;
    } else {
	$timestr	= &Time2String(time() - $time) ." ago";
    }

    &status(">>> set by $b_cyan$setby$ob $timestr");
}

sub on_crversion {
    my ($self, $event) = @_;
    my $nick	= $event->nick();
    my $ver;

    if (scalar $event->args() != 1) {	# old.
	$ver	= join ' ', $event->args();
	$ver	=~ s/^VERSION //;
    } else {				# new.
	$ver	= ($event->args())[0];
    }

    if (grep /^\Q$nick\E$/i, @vernick) {
	&WARN("nick $nick found in vernick ($ver); skipping.");
	return;
    }
    push(@vernick, $nick);

    if ($ver =~ /bitchx/i) {
	$ver{bitchx}{$nick}	= $ver;

    } elsif ($ver =~ /xc\!|xchat/i) {
	$ver{xchat}{$nick}	= $ver;

    } elsif ($ver =~ /irssi/i) {
	$ver{irssi}{$nick}	= $ver;

    } elsif ($ver =~ /epic|(Third Eye)/i) {
	$ver{epic}{$nick}	= $ver;

    } elsif ($ver =~ /ircII|PhoEniX/i) {
	$ver{ircII}{$nick}	= $ver;

    } elsif ($ver =~ /mirc/i) {
#	&DEBUG("verstats: mirc: $nick => '$ver'.");
	$ver{mirc}{$nick}	= $ver;

# ok... then we get to the lesser known/used clients.
    } elsif ($ver =~ /ircle/i) {
	$ver{ircle}{$nick}	= $ver;

    } elsif ($ver =~ /chatzilla/i) {
	$ver{chatzilla}{$nick}	= $ver;

    } elsif ($ver =~ /pirch/i) {
	$ver{pirch}{$nick}	= $ver;

    } elsif ($ver =~ /sirc /i) {
	$ver{sirc}{$nick}	= $ver;

    } elsif ($ver =~ /kvirc/i) {
	$ver{kvirc}{$nick}	= $ver;

    } elsif ($ver =~ /eggdrop/i) {
	$ver{eggdrop}{$nick}	= $ver;

    } elsif ($ver =~ /xircon/i) {
	$ver{xircon}{$nick}	= $ver;

    } else {
	&DEBUG("verstats: other: $nick => '$ver'.");
	$ver{other}{$nick}	= $ver;
    }
}

sub on_version {
    my ($self, $event) = @_;
    my $nick = $event->nick;

    &status(">>> ${b_green}CTCP VERSION$ob request from $b_cyan$nick$ob");
    $self->ctcp_reply($nick, "VERSION $bot_version");
}

sub on_who {
    my ($self, $event) = @_;
    my @args	= $event->args;
    my $str	= $args[5]."!".$args[2]."\@".$args[3];

    if ($cache{on_who_Hack}) {
	$cache{nuhInfo}{lc $args[5]}{Nick} = $args[5];
	$cache{nuhInfo}{lc $args[5]}{User} = $args[2];
	$cache{nuhInfo}{lc $args[5]}{Host} = $args[3];
	$cache{nuhInfo}{lc $args[5]}{NUH}  = "$args[5]!$args[2]\@$args[3]";
	return;
    }

    if ($args[5] =~ /^nickserv$/i and !$nickserv) {
	&DEBUG("ok... we did a who for nickserv.");
	&rawout("PRIVMSG NickServ :IDENTIFY $param{'nickServ_pass'}");
    }

    $nuh{lc $args[5]} = $args[5]."!".$args[2]."\@".$args[3];
}

sub on_whois {
    my ($self, $event) = @_;
    my @args	= $event->args;

    $nuh{lc $args[1]} = $args[1]."!".$args[2]."\@".$args[3];
}

sub on_whoischannels {
    my ($self, $event) = @_;
    my @args	= $event->args;

    &DEBUG("on_whoischannels: @args");
}

sub on_useronchannel {
    my ($self, $event) = @_;
    my @args	= $event->args;

    &DEBUG("on_useronchannel: @args");
    &joinNextChan();
}

###
### since joinnextchan is hooked onto on_endofnames, these are needed.
###

sub on_chanfull {
    my ($self, $event) = @_;
    my @args	= $event->args;

    &status(">>> chanfull/$b_blue$args[1]$ob");

    &joinNextChan();
}

sub on_inviteonly {
    my ($self, $event) = @_;
    my @args	= $event->args;

    &status(">>> inviteonly/$b_cyan$args[1]$ob");

    &joinNextChan();
}

sub on_banned {
    my ($self, $event) = @_;
    my @args	= $event->args;
    my $chan	= $args[1];

    &status(">>> banned/$b_blue$chan$ob $b_cyan$args[0]$ob");

    &joinNextChan();
}

sub on_badchankey {
    my ($self, $event) = @_;
    my @args	= $event->args;

    &DEBUG("on_badchankey: args => @args");
    &joinNextChan();
}

sub on_useronchan {
    my ($self, $event) = @_;
    my @args	= $event->args;

    &DEBUG("on_useronchan: args => @args");
    &joinNextChan();
}

1;
