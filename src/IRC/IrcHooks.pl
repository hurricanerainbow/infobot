#
# IrcHooks.pl: IRC Hooks stuff.
#      Author: dms
#     Version: 20000126
#        NOTE: Based on code by Kevin Lenzo & Patrick Cole  (c) 1997
#

if (&IsParam("useStrict")) { use strict; }

my $nickserv	= 0;

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
    my $nick = $event->nick();

    if (!exists $nuh{lc $nick}) {
	&DEBUG("chat: nuh{$nick} doesn't exist; hrm should retry.");
	return;
    } else {
	$message	= $msg;
	$who		= lc $nick;
	$orig{who}	= $nick;
	$orig{message}	= $msg;
	$nuh		= $nuh{$who};
	$uh		= (split /\!/, $nuh)[1];
	$addressed	= 1;
	$msgType	= 'chat';
    }

    if (!exists $dcc{'CHAT'}{$nick}) {
	my $userHandle	= &verifyUser($who, $nuh);
	my $crypto	= $userList{$userHandle}{'pass'};
	my $success	= 0;

	if (!defined $crypto) {
	    &DEBUG("chat: no pass required.");
	    $success++;
	} elsif (&ckpasswd($msg, $crypto)) {
	    $self->privmsg($sock,"Authorized.");
	    $self->privmsg($sock,"I'll respond as if through /msg and addressed in public. Addition to that, access to 'user' commands will be allowed, like 'die' and 'jump'.");
	    # hrm... it's stupid to ask for factoids _within_ dcc chat.
	    # perhaps it should be default to commands, especially
	    # commands only authorized through DCC CHAT.
	    &status("DCC CHAT: passwd is ok.");
	    $success++;
	} else {
	    &status("DCC CHAT: incorrect pass; closing connection.");
	    &DEBUG("chat: sock => '$sock'.");
###	    $sock->close();
	    &DEBUG("chat: after closing sock. FIXME");
	    ### BUG: close seizes bot. why?
	}

	if ($success) {
	    &status("DCC CHAT: user $nick is here!");
	    $dcc{'CHAT'}{$nick} = $sock;
	    &DCCBroadcast("$nick ($uh) has joined the chat arena.");
	}

	return;
    }


    $userHandle = &verifyUser($who, $nuh);
    &status("$b_red=$b_cyan$who$b_red=$ob $message");
    if ($message =~ s/^\.//) {	# dcc chat commands.
	### TODO: make use of &Forker(); here?
	&loadMyModule($myModules{'ircdcc'});
	return '$noreply from userD' if (&userDCC() eq $noreply);
	$conn->privmsg($dcc{'CHAT'}{$who}, "Invalid command.");

    } else {			# dcc chat arena.
	foreach (keys %{$dcc{'CHAT'}}) {
	    $conn->privmsg($dcc{'CHAT'}{$_}, "<$who> $orig{message}");
	}
    }

    return 'DCC CHAT MESSAGE';
}

sub on_endofmotd {
    my ($self) = @_;

    if (&IsParam("wingate")) {
	my $file = "$bot_base_dir/$param{'ircUser'}.wingate";
	open(IN, $file);
	while (<IN>) {
	    chop;
	    next unless (/^(\S+)\*$/);
	    push(@wingateBad, $_);
	}
	close IN;
    }

    ### TODO: move this to end of &joinNextChan()?
    if ($firsttime) {
	&DEBUG("on_EOM: calling sS in 60s.");
	$conn->schedule(60, \&setupSchedulers, "");
	$firsttime = 0;
    }

    if (&IsParam("ircUMode")) {
	&status("Changing user modes to $param{'ircUMode'}.");
	&rawout("MODE $ident $param{'ircUMode'}");
    }

    &status("End of motd. Now lets join some channels...");
    if (!scalar @joinchan) {
	&WARN("joinchan array is empty!!!");
	@joinchan = split /[\t\s]+/, $param{'join_channels'};
    }

    &joinNextChan();
}

sub on_dcc {
    my ($self, $event) = @_;
    my $type = uc( ($event->args)[1] );
    my $nick = $event->nick();

    # pity Net::IRC doesn't store nuh. Here's a hack :)
    $self->whois($nick);

    if ($type eq 'SEND') {
	# incoming DCC SEND. we're receiving a file.
	$self->new_get($event, \*FH);
    } elsif ($type eq 'CHAT') {
	$self->new_chat($event);
    } else {
	&status("${b_green}DCC $type$ob unknown ...");
    }
}

sub on_dcc_close {
    my ($self, $event) = @_;
    my $nick = $event->nick();
    my $sock = ($event->to)[0];

    &DEBUG("dcc_close: nick => '$nick'.");

    if (exists $dcc{'SEND'}{$nick} and -f "temp/$nick.txt") {
	&status("${b_green}DCC SEND$ob close from $b_cyan$nick$ob");

	&status("dcc_close: purging $nick.txt from Debian.pl");
	unlink "temp/$nick.txt";

	delete $dcc{'SEND'}{$nick};
    } elsif (exists $dcc{'CHAT'}{$nick} and $dcc{'CHAT'}{$nick} eq $sock) {
	&status("${b_green}DCC CHAT$ob close from $b_cyan$nick$ob");
	delete $dcc{'CHAT'}{$nick};
    } else {
	&status("${b_green}DCC$ob UNKNOWN close from $b_cyan$nick$ob");
    }
}

sub on_dcc_open {
    my ($self, $event) = @_;
    my $type = uc( ($event->args)[0] );
    my $nick = $event->nick();
    my $sock = ($event->to)[0];
    $msgType = 'chat';

    if ($type eq 'SEND') {
	&status("${b_green}DCC lGET$ob established with $b_cyan$nick$ob");
    } elsif ($type eq 'CHAT') {
	&status("${b_green}DCC CHAT$ob established with $b_cyan$nick$ob ($nuh{$nick})");
	my $userHandle  = &verifyUser($nick, $nuh{lc $nick});
	my $crypto	= $userList{$userHandle}{'pass'};
	if (defined $crypto) {
	    $self->privmsg($sock,"Enter Password, $userHandle.");
	} else {
	    $self->privmsg($sock,"Welcome to blootbot DCC CHAT interface, $userHandle.");
	}
    } else {
	&status("${b_green}DCC $type$ob unknown ...");
    }
}

sub on_disconnect {
    my ($self, $event) = @_;
    my $from = $event->from();
    my $what = ($event->args)[0];

    &status("disconnect from $from ($what).");
    $ircstats{'DisconnectReason'} = $what;

    # clear any variables on reconnection.
    $nickserv = 0;

    &clearIRCVars();

    if (!$self->connect()) {
	&WARN("not connected? help me. ircCheck() should reconnect me");
    }
}

sub on_endofnames {
    my ($self, $event) = @_;
    my $chan = ($event->args)[1];

    if (exists $jointime{$chan}) {
	my $delta_time = sprintf("%.03f", &gettimeofday() - $jointime{$chan});
	$delta_time    = 0	if ($delta_time < 0);

	&status("$b_blue$chan$ob: sync in ${delta_time}s.");
    }

    rawout("MODE $chan");

    my $txt;
    my @array;
    foreach ("o","v","") {
	my $count = scalar(keys %{$channels{$chan}{$_}});
	next unless ($count);

	$txt = "total" if ($_ eq "");
	$txt = "voice" if ($_ eq "v");
	$txt = "ops"   if ($_ eq "o");

	push(@array, "$count $txt");
    }
    my $chanstats = join(' || ', @array);
    &status("$b_blue$chan$ob: [$chanstats]");

    if (scalar @joinchan) {	# remaining channels to join.
	&joinNextChan();
    } else {
	### chanserv support.
	### TODO: what if we rejoin a channel.. need to set a var that
	###	  we've done the request-for-ops-on-join.
	return unless (&IsParam("chanServ_ops"));
	return unless ($nickserv);

	my @chans = split(/[\s\t]+/, $param{'chanServ_ops'});

	foreach $chan (keys %channels) {
	    next unless (grep /^$chan$/i, @chans);

	    if (!exists $channels{$chan}{'o'}{$ident}) {
		&status("ChanServ ==> Requesting ops for $chan.");
		rawout("PRIVMSG ChanServ :OP $chan $ident");
	    }
	}
    }

}

sub on_init {
    my ($self, $event) = @_;
    my (@args) = ($event->args);
    shift @args;

    &status("@args");
}

sub on_invite {
    my ($self, $event) = @_;
    my $chan = ($event->args)[0];
    my $nick = $event->nick;

    &DEBUG("on_invite: chan => '$chan', nick => '$nick'.");

    # chan + possible_key.
    ### do we need to know the key if we're invited???
    ### grep the channel list?
    foreach (split /[\s\t]+/, $param{'join_channels'}) {
	next unless /^\Q$chan\E(,\S+)?$/i;
	s/,/ /;

	next if ($nick =~ /^\Q$ident\E$/);
	if (&validChan($chan)) {
	    &msg($who, "i'm already in \002$chan\002.");
	    next;
	}

	&status("invited to $b_blue$_$ob by $b_cyan$who$ob");
	&joinchan($self, $_);
    }
}

sub on_join {
    my ($self, $event) = @_;
    my ($user,$host) = split(/\@/, $event->userhost);
    $chan	= lc( ($event->to)[0] );	# CASING!!!!
    $who	= $event->nick();

    $chanstats{$chan}{'Join'}++;
    $userstats{lc $who}{'Join'} = time() if (&IsParam("seenStats"));

    # netjoin detection.
    my $netsplit = 0;
    if (exists $netsplit{lc $who}) {
	delete $netsplit{lc $who};
	$netsplit = 1;
    }

    # how to tell if there's a netjoin???

    my $netsplitstr = "";
    $netsplitstr = " $b_yellow\[${ob}NETSPLIT VICTIM$b_yellow]$ob" if ($netsplit);
    &status(">>> join/$b_blue$chan$ob $b_cyan$who$ob $b_yellow($ob$user\@$host$b_yellow)$ob$netsplitstr");

    $channels{$chan}{''}{$who}++;
    $nuh{lc $who} = $who."!".$user."\@".$host unless (exists $nuh{lc $who});

    ### ROOTWARN:
    &rootWarn($who,$user,$host,$chan)
		if (&IsParam("rootWarn") &&
		    $user =~ /^r(oo|ew|00)t$/i &&
		    $channels{$chan}{'o'}{$ident});

    # used to determine sync time.
    if ($who =~ /^$ident$/i) {
	if (defined( my $whojoin = $joinverb{$chan} )) {
	    &msg($chan, "Okay, I'm here. (courtesy of $whojoin)");
	    delete $joinverb{$chan};
	}

	### TODO: move this to &joinchan()?
	$jointime{$chan} = &gettimeofday();
	rawout("WHO $chan");
    } else {
	### TODO: this may go wild on a netjoin :)
	### WINGATE:
	&wingateCheck();
    }
}

sub on_kick {
    my ($self, $event) = @_;
    my ($chan,$reason) = $event->args;
    my $kicker	= $event->nick;
    my $kickee	= ($event->to)[0];
    my $uh	= $event->userhost();

    &status(">>> kick/$b_blue$chan$ob [$b$kickee!$uh$ob] by $b_cyan$kicker$ob $b_yellow($ob$reason$b_yellow)$ob");

    $chanstats{$chan}{'Kick'}++;

    if ($kickee eq $ident) {
	&clearChanVars($chan);

	&status("SELF attempting to rejoin lost channel $chan");
	&joinchan($chan);
    } else {
	&DeleteUserInfo($kickee,$chan);
    }
}

sub on_mode {
    my ($self, $event)	= @_;
    my ($user, $host)	= split(/\@/, $event->userhost);
    my @args = $event->args();
    my $nick = $event->nick();
    my $chan = ($event->to)[0];

    $args[0] =~ s/\s$//;

    if ($nick eq $chan) {	# UMODE
	&status(">>> mode $b_yellow\[$ob$b@args$b_yellow\]$ob by $b_cyan$nick$ob");
    } else {			# MODE
	&status(">>> mode/$b_blue$chan$ob $b_yellow\[$ob$b@args$b_yellow\]$ob by $b_cyan$nick$ob");
	&hookMode($chan, @args);
    }
}

sub on_modeis {
    my ($self, $event) = @_;
    my $nick = $event->nick();
    my ($myself,$chan,@args) = $event->args();

    &hookMode(lc $chan, @args);		# CASING.
}

sub on_msg {
    my ($self, $event) = @_;
    my $nick = $event->nick;
    my $chan = lc ( ($event->to)[0] );	# CASING.
    my $msg = ($event->args)[0];

    ($user,$host) = split(/\@/, $event->userhost);
    $uh		= $event->userhost();
    $nuh	= $nick."!".$uh;

    &hookMsg('private', $chan, $nick, $msg);
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

    my ($chan,$mode);
    foreach $chan (keys %channels) {
	foreach $mode (keys %{$channels{$chan}}) {
	    next unless (exists $channels{$chan}{$mode}{$nick});

	    $channels{$chan}{$mode}{$newnick} = $channels{$chan}{$mode}{$nick};
	}
    }
    &DeleteUserInfo($nick,keys %channels);
    $nuh{lc $newnick} = $nuh{lc $nick};
    delete $nuh{lc $nick};

    # successful self-nick change.
    if ($nick eq $ident) {
	&status(">>> I materialized into $b_green$newnick$ob from $nick");
	$ident = $newnick;
    } else {
	&status(">>> $b_cyan$nick$ob materializes into $b_green$newnick$ob");
    }
}

sub on_nick_taken {
    my ($self) = @_;
    my $nick = $self->nick;
    my $newnick = substr($nick,0,8).int(rand(10));

    &DEBUG("on_nick_taken: changing nick to $newnick.");
    $self->nick($newnick);
    $ident	= $newnick;
}

sub on_notice {
    my ($self, $event) = @_;
    my $nick = $event->nick();
    my $chan = ($event->to)[0];
    my $args = ($event->args)[0];

    if ($nick =~ /^NickServ$/i) {		# nickserv.
	&status("NickServ: <== '$args'");

	if ($args =~ /^This nickname is registered/i) {
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
    my $chan = lc( ($event->to)[0] );	# CASING!!!
    my $nick = $event->nick;
    my $userhost = $event->userhost;

    $chanstats{$chan}{'Part'}++;
    &DeleteUserInfo($nick,$chan);
    &clearChanVars($chan) if ($nick eq $ident);
    if (!&IsNickInAnyChan($nick) and &IsParam("seenStats")) {
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
    my $nick = $event->nick;
    my $lag = time() - ($event->args)[1];

    &status(">>> ${b_green}CTCP PING$ob reply from $b_cyan$nick$ob: $lag sec.");
}

sub on_public {
    my ($self, $event) = @_;
    my $msg  = ($event->args)[0];
    my $chan = lc( ($event->to)[0] );	# CASING.
    my $nick = $event->nick;
    $uh      = $event->userhost();
    $nuh     = $nick."!".$uh;
    ($user,$host) = split(/\@/, $uh);

    ### DEBUGGING.
    if ($statcount < 200) {
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


    $msgtime = time();
    $lastWho{$chan} = $nick;
    ### TODO: use $nick or lc $nick?
    if (&IsParam("seenStats")) {
	$userstats{lc $nick}{'Count'}++;
	$userstats{lc $nick}{'Time'} = time();
    }

#    if (&IsParam("hehCounter")) {
#	#...
#    }

    &hookMsg('public', $chan, $nick, $msg);
    $chanstats{$chan}{'PublicMsg'}++;
}

sub on_quit {
    my ($self, $event) = @_;
    my $nick = $event->nick();
    my $reason = ($event->args)[0];

    foreach (keys %channels) {
	# fixes inconsistent chanstats bug #1.
	next unless (&IsNickInChan($nick,$_));
	$chanstats{$_}{'SignOff'}++;
    }
    &DeleteUserInfo($nick, keys %channels);
    if (exists $nuh{lc $nick}) {
	delete $nuh{lc $nick};
    } else {
	&DEBUG("on_quit: nuh{lc $nick} does not exist! FIXME");
    }
    delete $userstats{lc $nick} if (&IsParam("seenStats"));

    # should fix chanstats inconsistencies bug #2.
    if ($reason=~/^($mask{host})\s($mask{host})$/) {	# netsplit.
	$reason = "NETSPLIT: $1 <=> $2";

	$netsplit{lc $nick} = time();
	if (!exists $netsplitservers{$1}{$2}) {
	    &status("netsplit detected between $1 and $2.");
	    $netsplitservers{$1}{$2} = time();
	}
    }

    &status(">>> $b_cyan$nick$ob has signed off IRC $b_red($ob$reason$b_red)$ob");
    if ($nick =~ /^\Q$ident\E$/) {
	&DEBUG("!!! THIS SHOULD NEVER HAPPEN. FIXME HOPEFULLY");
    }
    if ($nick !~ /^\Q$ident\E$/ and $nick =~ /^\Q$param{'ircNick'}\E$/i) {
	&status("own nickname became free; changing.");
	&nick($param{'ircNick'});
    }
}

sub on_targettoofast {
    my ($self, $event) = @_;
    my $nick = $event->nick();
    my $chan = ($event->to)[0];

    &DEBUG("on_targettoofast: nick => '$nick'.");
    &DEBUG("on_targettoofast: chan => '$chan'.");

    foreach ($event->args) {
	&DEBUG("on_targettoofast: args => '$_'.");
    }

###    .* wait (\d+) second/) {
	&status($msg);
	my $sleep = $3 + 10;

	&status("going to sleep for $sleep...");
	sleep $sleep;
	&joinNextChan();
### }
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

	$topic{$chan}{'Current'} = $topic if (1 and &IsParam("topic") == 1);
	$chanstats{$chan}{'Topic'}++;

	&status(">>> topic/$b_blue$chan$ob by $b_cyan$nick$ob -> $topic");
    } else {						# join.
	my ($nick, $chan, $topic) = $event->args;
	if (&IsParam("topic")) {
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

sub on_version {
    my ($self, $event) = @_;
    my $nick = $event->nick;

    &status(">>> ${b_green}CTCP VERSION$ob request from $b_cyan$nick$ob");
    $self->ctcp_reply($nick, "VERSION $bot_version");
}

sub on_who {
    my ($self, $event) = @_;
    my @args	= $event->args;

    $nuh{lc $args[5]} = $args[5]."!".$args[2]."\@".$args[3];
}

sub on_whoisuser {
    my ($self, $event) = @_;
    my @args	= $event->args;

    $nuh{lc $args[1]} = $args[1]."!".$args[2]."\@".$args[3];
}

#######################################################################
####### IRC HOOK HELPERS   IRC HOOK HELPERS   IRC HOOK HELPERS ########
#######################################################################

#####
# Usage: &hookMode($chan, $modes, @targets);
sub hookMode {
    my ($chan, $modes, @targets) = @_;
    my $parity	= 0;

    $chan = lc $chan;		# !!!.

    my $mode;
    foreach $mode (split(//, $modes)) {
	# sign.
	if ($mode =~ /[-+]/) {
	    $parity = 1		if ($mode eq "+");
	    $parity = 0		if ($mode eq "-");
	    next;
	}

	# mode with target.
	if ($mode =~ /[bklov]/) {
	    my $target = shift @targets;

	    if ($parity) {
		$chanstats{$chan}{'Op'}++    if ($mode eq "o");
		$chanstats{$chan}{'Ban'}++   if ($mode eq "b");
	    } else {
		$chanstats{$chan}{'Deop'}++  if ($mode eq "o");
		$chanstats{$chan}{'Unban'}++ if ($mode eq "b");
	    }

	    # modes w/ target affecting nick => cache it.
	    if ($mode =~ /[ov]/) {
		$channels{$chan}{$mode}{$target}++	if  $parity;
		delete $channels{$chan}{$mode}{$target}	if !$parity;
	    }

	    if ($mode =~ /[l]/) {
		$channels{$chan}{$mode} = $target	if  $parity;
		delete $channels{$chan}{$mode}		if !$parity;
	    }
	}

	# important channel modes, targetless.
	if ($mode =~ /[mt]/) {
	    $channels{$chan}{$mode}++			if  $parity;
	    delete $channels{$chan}{$mode}		if !$parity;
	}
    }
}

sub hookMsg {
    ($msgType, $chan, $who, $message) = @_;
    my $skipmessage	= 0;
    $addressed		= 0;
    $addressedother	= 0;
    $orig{message}	= $message;
    $orig{who}		= $who;
    $addrchar		= 0;

    $message	=~ s/[\cA-\c_]//ig;	# strip control characters
    $message	=~ s/^\s+//;		# initial whitespaces.
    $who	=~ tr/A-Z/a-z/;		# lowercase.

    &showProc();

    # addressing.
    if ($msgType =~ /private/) {
	# private messages.
	$addressed = 1;
    } else {
	# public messages.
	# addressing revamped by the xk.
	### below needs to be fixed...
	if (&IsParam("addressCharacter")) {
	    if ($message =~ s/^$param{'addressCharacter'}//) {
		$addrchar  = 1;
		$addressed = 1;
	    }
	}

	if ($message =~ /^($mask{nick})([\;\:\>\, ]+) */) {
	    my $newmessage = $';
	    if ($1 =~ /^\Q$ident\E$/i) {
		$message   = $newmessage;
		$addressed = 1;
	    } else {
		# ignore messages addressed to other people or unaddressed.
		$skipmessage++ if ($2 ne "" and $2 !~ /^ /);
	    }
	}
    }

    # Determine floodwho.
    if ($msgType =~ /public/i) {		# public.
	$floodwho = lc $chan;
    } elsif ($msgType =~ /private/i) {	# private.
	$floodwho = lc $who;
    } else {				# dcc?
	&DEBUG("FIXME: floodwho = ???");
    }

    my ($count, $interval) = split(/:/, $param{'floodRepeat'} || "2:10");

    # flood repeat protection.
    if ($addressed) {
	my $time = $flood{$floodwho}{$message};

	if (defined $time and (time - $time < $interval)) {
	    ### public != personal who so the below is kind of pointless.
	    my @who;
	    foreach (keys %flood) {
		next if (/^\Q$floodwho\E$/ or /^\Q$chan\E$/);
		push(@who, grep /^\Q$message\E$/i, keys %{$flood{$_}});
	    }
	    if (scalar @who) {
		&msg($who, "you already said what ".join(@who)." have said.");
	    } else {
		&msg($who,"Someone already said that ". (time - $time) ." seconds ago" );
	    }

	    ### TODO: delete old floodwarn{} keys.
	    my $floodwarn = 0;
	    if (!exists $floodwarn{$floodwho}) {
		$floodwarn++;
	    } else {
		$floodwarn++ if (time() - $floodwarn{$floodwho} > $interval);
	    }

	    if ($floodwarn) {
		&status("FLOOD repetition detected from $floodwho.");
		$floodwarn{$floodwho} = time();
	    }

	    return;
	}

	if ($addrchar) {
	    &status("$b_cyan$who$ob is short-addressing me");
	} else {
	    &status("$b_cyan$who$ob is addressing me");
	}

	$flood{$floodwho}{$message} = time();
    }

    ($count, $interval) = split(/:/, $param{'floodMessages'} || "5:30");
    # flood overflow protection.
    if ($addressed) {
	foreach (keys %{$flood{$floodwho}}) {
	    next unless (time() - $flood{$floodwho}{$_} > $interval);
	    delete $flood{$floodwho}{$_};
	}

	my $i = scalar keys %{$flood{$floodwho}};
	if ($i > $count) {
	    &msg($who,"overflow of messages ($i > $count)");
	    &status("FLOOD overflow detected from $floodwho; ignoring");

	    my $expire = $param{'ignoreAutoExpire'} || 5;
	    $ignoreList{"*!$uh"} = time() + ($expire * 60);
	    return;
	}

	$flood{$floodwho}{$message} = time();
    }

    # public.
    if ($msgType =~ /public/i) {
	$talkchannel = $chan;
	&status("<$orig{who}/$chan> $orig{message}");
    }

    # private.
    if ($msgType =~ /private/i) {
	&status("[$orig{who}] $orig{message}");
    }

    return if ($skipmessage);
    return unless (&IsParam("minVolunteerLength") or $addressed);

    local $ignore = 0;
    foreach (keys %ignoreList) {
	my $ignoreRE = $_;
	my @parts = split /\*/, "a${ignoreRE}a";
	my $recast = join '\S*', map quotemeta($_), @parts;
	$recast =~ s/^a(.*)a$/$1/;
	if ($nuh =~ /^$recast$/) {
	    $ignore++;
	    last;
	}
    }

    if (defined $nuh) {
	$userHandle = &verifyUser($who, $nuh);
    } else {
	&DEBUG("hookMsg: 'nuh' not defined?");
    }

### For extra debugging purposes...
    if ($_ = &process()) {
#	&DEBUG("IrcHooks: process returned '$_'.");
    }

    return;
}

1;
