#
#    Irc.pl: IRC core stuff.
#    Author: dms
#   Version: 20000126
#      NOTE: Based on code by Kevin Lenzo & Patrick Cole  (c) 1997
#

if (&IsParam("useStrict")) { use strict; }

use vars qw($nickserv);
$nickserv	= 0;

# static scalar variables.
$mask{ip}	= '(\d+)\.(\d+)\.(\d+)\.(\d+)';
$mask{host}	= '[\d\w\_\-\/]+\.[\.\d\w\_\-\/]+';
$mask{chan}	= '[\#\&]\S*|_default';
my $isnick1	= 'a-zA-Z\[\]\{\}\_\`\^\|\\\\';
my $isnick2	= '0-9\-';
$mask{nick}	= "[$isnick1]{1}[$isnick1$isnick2]*";
$mask{nuh}	= '\S*!\S*\@\S*';

sub ircloop {
    my $error	= 0;
    my $lastrun = 0;

loop:;
    while (my $host = shift @ircServers) {
	# JUST IN CASE. irq was complaining about this.
	if ($lastrun == time()) {
	    &DEBUG("hrm... lastrun == time()");
	    $error++;
	    sleep 10;
	    next;
	}

	if (!defined $host) {
	    &DEBUG("ircloop: ircServers[x] = NULL.");
	    $lastrun = time();
	    next;
	}
	next unless (exists $ircPort{$host});

	my $retval = &irc($host, $ircPort{$host});
	&DEBUG("ircloop: after irc()");

	next unless (defined $retval and $retval == 0);

	$error++;

	if ($error % 3 == 0 and $error != 0) {
	    &ERROR("CANNOT connect to this server; next!");
	    next;
	}

	if ($error >= 3*3) {
	    &ERROR("CANNOT connect to any irc server; stopping.");
	    exit 1;
	}
    }

    &DEBUG("ircloop: end... going back.");
    &loadIRCServers();
    goto loop;
}

sub irc {
    my ($server,$port) = @_;

    my $iaddr = inet_aton($server);
    my $paddr = sockaddr_in($port, $iaddr);
    my $proto = getprotobyname('tcp');

    select STDOUT;
    &status("Connecting to port $port of server $server ...");

    # host->ip.
    if ($server =~ /\D$/) {
	my $packed = scalar(gethostbyname($server));

	if (!defined $packed) {
	    &status("  cannot resolve $server.");
	    return 0;
	}

	my $resolve = inet_ntoa($packed);
	&status("  resolved to $resolve.");
	### warning in Sys/Hostname line 78???
	### caused inside Net::IRC?
    }

    $irc = new Net::IRC;

    $conn = $irc->newconn(
		Nick	=> $param{'ircNick'},
		Server	=> $server,
		Port	=> $port,
		Ircname	=> $param{'ircName'},
		LocalAddr => $param{'ircHost'},
    );

    if (!defined $conn) {
	&ERROR("irc: conn was not created!defined!!!");
	return 1;
    }

    &clearIRCVars();

    # change internal timeout value for scheduler.
    $irc->{_timeout}	= 10;	# how about 60?

    $ircstats{'Server'}	= "$server:$port";

    # handler stuff.
	$conn->add_handler('caction',	\&on_action);
	$conn->add_handler('cdcc',	\&on_dcc);
	$conn->add_handler('cping',	\&on_ping);
	$conn->add_handler('crping',	\&on_ping_reply);
	$conn->add_handler('cversion',	\&on_version);
	$conn->add_handler('crversion',	\&on_crversion);
	$conn->add_handler('dcc_open',	\&on_dcc_open);
	$conn->add_handler('dcc_close',	\&on_dcc_close);
	$conn->add_handler('chat',	\&on_chat);
	$conn->add_handler('msg',	\&on_msg);
	$conn->add_handler('public',	\&on_public);
	$conn->add_handler('join',	\&on_join);
	$conn->add_handler('part',	\&on_part);
	$conn->add_handler('topic',	\&on_topic);
	$conn->add_handler('invite',	\&on_invite);
	$conn->add_handler('kick',	\&on_kick);
	$conn->add_handler('mode',	\&on_mode);
	$conn->add_handler('nick',	\&on_nick);
	$conn->add_handler('quit',	\&on_quit);
	$conn->add_handler('notice',	\&on_notice);
	$conn->add_handler('whoisuser',	\&on_whoisuser);
	$conn->add_handler('other',	\&on_other);
	$conn->add_global_handler('disconnect', \&on_disconnect);
	$conn->add_global_handler([251,252,253,254,255], \&on_init);
###	$conn->add_global_handler([251,252,253,254,255,302], \&on_init);
	$conn->add_global_handler(324, \&on_modeis);
	$conn->add_global_handler(333, \&on_topicinfo);
	$conn->add_global_handler(352, \&on_who);
	$conn->add_global_handler(353, \&on_names);
	$conn->add_global_handler(366, \&on_endofnames);
	$conn->add_global_handler(376, \&on_endofmotd); # on_connect.
	$conn->add_global_handler(433, \&on_nick_taken);
	$conn->add_global_handler(439, \&on_targettoofast);

    # end of handler stuff.

    $irc->start;
}

######################################################################
######## IRC ALIASES   IRC ALIASES   IRC ALIASES   IRC ALIASES #######
######################################################################

sub rawout {
    my ($buf) = @_;
    $buf =~ s/\n//gi;

    # slow down a bit if traffic is "high".
    # need to take into account time of last message sent.
    if ($last{buflen} > 256 and length($buf) > 256) {
	sleep 1;
    }

    $conn->sl($buf) if (&whatInterface() =~ /IRC/);

    $last{buflen} = length($buf);
}

sub say {
    my ($msg) = @_;
    if (!defined $msg) {
	$msg ||= "NULL";
	&DEBUG("say: msg == $msg.");
	return;
    }

    if ($msg eq $last{say} and length($msg) > 256) {
	&status("say: detected repeated message; skipping.");
	return;
    }
    $last{say} = $msg;

    &status("</$talkchannel> $msg");
    if (&whatInterface() =~ /IRC/) {
	$msg = "zero" if ($msg =~ /^0+$/);

	$conn->privmsg($talkchannel, $msg);
    }
}

sub msg {
    my ($nick, $msg) = @_;
    if (!defined $nick) {
	&ERROR("msg: nick == NULL.");
	return;
    }

    if (!defined $msg) {
	$msg ||= "NULL";
	&DEBUG("msg: msg == $msg.");
	return;
    }

    if ($msg eq $last{msg} and length($msg) > 256) {
	&status("msg: detected repeated message; skipping.");
	return;
    }
    $last{msg} = $msg;

    &status(">$nick< $msg");
    $conn->privmsg($nick, $msg) if (&whatInterface() =~ /IRC/);
}

# Usage: &action(nick || chan, txt);
sub action {
    my ($target, $txt) = @_;
    if (!defined $txt) {
	&DEBUG("action: txt == NULL.");
	return;
    }

    my $rawout = "PRIVMSG $target :\001ACTION $txt\001";
    if (length $rawout > 510) {
	&status("action: txt too long; truncating.");

	chop($rawout) while (length($rawout) > 510);
	$rawout .= "\001";
    }

    &status("* $ident/$target $txt");
    rawout($rawout);
}

# Usage: &action(nick || chan, txt);
sub notice{
    my ($target, $txt) = @_;
    if (!defined $txt) {
	&DEBUG("action: txt == NULL.");
	return;
    }

    &status("-$target- $txt");

    $conn->notice($target, $txt);
}


sub DCCBroadcast {
    my ($txt,$flag) = @_;

    ### FIXME: flag not supported yet.

    foreach (keys %{$dcc{'CHAT'}}) {
	$conn->privmsg($dcc{'CHAT'}{$_}, $txt);
    }
}

##########
### perform commands.
###

# Usage: &performReply($reply);
sub performReply {
    my ($reply) = @_;
    $reply =~ /([\.\?\s]+)$/;

    &checkMsgType($reply);

    if ($msgType eq 'public') {
	if (rand() < 0.5 or $reply =~ /[\.\?]$/) {
	    $reply = "$orig{who}: ".$reply;
	} else {
	    $reply = "$reply, ".$orig{who};
	}
	&say($reply);
    } elsif ($msgType eq 'private') {
	if (rand() < 0.5) {
	    $reply = $reply;
	} else {
	    $reply = "$reply, ".$orig{who};
	}
	&msg($who, $reply);
    } elsif ($msgType eq 'chat') {
	if (!exists $dcc{'CHAT'}{$who}) {
	    &WARN("pSR: dcc{'CHAT'}{$who} does not exist.");
	    return;
	}
	$conn->privmsg($dcc{'CHAT'}{$who}, $reply);
    } else {
	&ERROR("PR: msgType invalid? ($msgType).");
    }
}

# ...
sub performAddressedReply {
    return unless ($addressed);
    &performReply(@_);
}

sub pSReply {
    &performStrictReply(@_);
}

# Usage: &performStrictReply($reply);
sub performStrictReply {
    my ($reply) = @_;

    &checkMsgType($reply);

    if ($msgType eq 'private') {
	&msg($who, $reply);
    } elsif ($msgType eq 'public') {
	&say($reply);
    } elsif ($msgType eq 'chat') {
	&dccsay(lc $who,$reply);
    } else {
	&ERROR("pSR: msgType invalid? ($msgType).");
    }
}

sub dccsay {
    my ($who, $reply) = @_;
    if (!exists $dcc{'CHAT'}{$who}) {
	&WARN("pSR: dcc{'CHAT'}{$who} does not exist.");
	return '';
    }

    &status("=>$who<= $reply");		# dcc chat.
    $conn->privmsg($dcc{'CHAT'}{$who}, $reply);
}

sub dcc_close {
    my($who) = @_;
    my $type;

    foreach $type (keys %dcc) {
	&FIXME("dcc_close: $who");
	my @who = grep /^\Q$who\E$/i, keys %{$dcc{$type}};
	next unless (scalar @who);
	$who = $who[0];
    }
}

sub joinchan {
    my ($chankey) = @_;
    my $chan = lc $chankey;

    if ($chankey =~ s/^($mask{chan}),\S+/ /) {
	$chan = lc $1;
    }

    &status("joining $b_blue$chan$ob");

    if (&validChan($chan)) {
	&status("join: already on $chan");
    } else {
	if (!$conn->join($chan)) {
	    &DEBUG("join failed. trying connect!");
	    $conn->connect();
	}
    }
}

sub part {
    my $chan;

    foreach $chan (@_) {
	next if ($chan eq "");
	$chan =~ tr/A-Z/a-z/;	# lowercase.

	&status("parting $chan");
	if (!&validChan($chan)) {
	    &status("part: not on $chan");
	    next;
	}

	rawout("PART $chan");
	# deletion of $channels{chan} is done in &entryEvt().
    }
}

sub mode {
    my ($chan, @modes) = @_;
    my $modes = join(" ", @modes);

    if (&validChan($chan) == 0) {
	&ERROR("mode: invalid chan => '$chan'.");
	return;
    }

    &DEBUG("MODE $chan $modes");

    rawout("MODE $chan $modes");
}

sub op {
    my ($chan, @who) = @_;
    my $os	= "o" x scalar(@who);

    &mode($chan, "+$os @who");
}

sub deop {
    my ($chan, @who) = @_;
    my $os = "o" x scalar(@who);

    &mode($chan, "-$os ".@who);
}

sub kick {
    my ($nick,$chan,$msg) = @_;
    my (@chans) = ($chan eq "") ? (keys %channels) : lc($chan);

    if ($chan ne "" and &validChan($chan) == 0) {
	&ERROR("kick: invalid channel $chan.");
	return;
    }

    $nick =~ tr/A-Z/a-z/;

    foreach $chan (@chans) {
	if (!&IsNickInChan($nick,$chan)) {
	    &status("Kick: $nick is not on $chan.") if (scalar @chans == 1);
	    next;
	}

	if (!exists $channels{$chan}{o}{$ident}) {
	    &status("Kick: do not have ops on $chan :(");
	    next;
	}

	&status("Kicking $nick from $chan.");
	if ($msg eq "") {
	    &rawout("KICK $chan $nick");
	} else {
	    &rawout("KICK $chan $nick :$msg");
	}
    }
}

sub ban {
    my ($mask,$chan) = @_;
    my (@chans) = ($chan =~ /^\*?$/) ? (keys %channels) : lc($chan);
    my $ban	= 0;

    if ($chan !~ /^\*?$/ and &validChan($chan) == 0) {
	&ERROR("ban: invalid channel $chan.");
	return;
    }

    foreach $chan (@chans) {
	if (!exists $channels{$chan}{o}{$ident}) {
	    &status("Ban: do not have ops on $chan :(");
	    next;
	}

	&status("Banning $mask from $chan.");
	&rawout("MODE $chan +b $mask");
	$ban++;
    }

    return $ban;
}

sub unban {
    my ($mask,$chan) = @_;
    my (@chans) = ($chan =~ /^\*?$/) ? (keys %channels) : lc($chan);
    my $ban	= 0;

    &DEBUG("unban: mask = $mask, chan = @chans");

    foreach $chan (@chans) {
	if (!exists $channels{$chan}{o}{$ident}) {
	    &status("unBan: do not have ops on $chan :(");
	    next;
	}

	&status("Removed ban $mask from $chan.");
	&rawout("MODE $chan -b $mask");
	$ban++;
    }

    return $ban;
}

sub quit {
    my ($quitmsg) = @_;
    &status("QUIT $param{'ircNick'} has quit IRC ($quitmsg)");
    $conn->quit($quitmsg);
}

sub nick {
    my ($nick) = @_;

    if ($nick =~ /^$mask{nick}$/) {
	rawout("NICK ".$nick);
	return 1;
    }

    return 0;
}

sub invite {
    my($who, $chan) = @_;
    rawout("INVITE $who $chan");
}


##########
# Channel related functions...
#

# Usage: &joinNextChan();
sub joinNextChan {
    if (scalar @joinchan) {
	my $chan = shift @joinchan;
	&joinchan($chan);

	if (my $i = scalar @joinchan) {
	    &status("joinNextChan: $i chans to join.");
	}
	return;
    }

    if (&IsParam("nickServ_pass") and $nickserv < 1) {
	&WARN("jNC: nickserv/chanserv not up.") if (!$nickserv);
	$nickserv--;
    }

    my %chan = &getChanConfList("chanServ");
    foreach $chan (keys %chan) {
	next unless ($chan{$chan} > 0);
	    
	if (!exists $channels{$chan}{'o'}{$ident}) {
	    &status("ChanServ ==> Requesting ops for $chan.");
	    &rawout("PRIVMSG ChanServ :OP $chan $ident");
	}
    }
}

# Usage: &GetNickInChans($nick,$chan);
sub GetNickInChans {
    my ($nick) = @_;
    my @array;

    foreach (keys %channels) {
	next unless (grep /^\Q$nick\E$/i, keys %{$channels{$_}{''}});
	push(@array, $_);
    }

    return @array;
}

# Usage: &GetNicksInChan($chan);
sub GetNicksInChan {
    my ($chan) = @_;
    my @array;

    return keys %{ $channels{$chan}{''} };
}

sub IsNickInChan {
    my ($nick,$chan) = @_;

    $chan =~ tr/A-Z/a-z/;	# not lowercase unfortunately.

    if (&validChan($chan) == 0) {
	&ERROR("INIC: invalid channel $chan.");
	return 0;
    }

    if (grep /^\Q$nick\E$/i, keys %{$channels{$chan}{''}}) {
	return 1;
    } else {
	foreach (keys %channels) {
	    next unless (/[A-Z]/);
	    &DEBUG("hash channels contains mixed cased chan!!!");
	}
	return 0;
    }
}

sub IsNickInAnyChan {
    my ($nick) = @_;

    foreach $chan (keys %channels) {
	next unless (grep /^\Q$nick\E$/i, keys %{$channels{$chan}{''}});
	return 1;
    }
    return 0;
}

# Usage: &validChan($chan);
sub validChan {
    my ($chan) = @_;

    if (lc $chan ne $chan) {
	&WARN("validChan: lc chan != chan. ($chan); fixing.");
	$chan =~ tr/A-Z/a-z/;
    }

    if (exists $channels{$chan}) {
	return 1;
    } else {
	return 0;
    }
}

###
# Usage: &DeleteUserInfo($nick,@chans);
sub DeleteUserInfo {
    my ($nick,@chans) = @_;
    my ($mode,$chan);

    foreach $chan (@chans) {
	foreach $mode (keys %{$channels{$chan}}) {
	    # use grep here?
	    next unless (exists $channels{$chan}{$mode}{$nick});

	    delete $channels{$chan}{$mode}{$nick};
	}
    }
}

sub clearChanVars {
    my ($chan) = @_;

    delete $channels{$chan};
}

sub clearIRCVars {
    &DEBUG("clearIRCVars() called!");
    undef %channels;
    undef %floodjoin;

    @joinchan	= &getJoinChans();
}

sub getJoinChans {
    my @chans;
    my @skip;

    foreach (keys %chanconf) {
	next if ($_ eq "_default");

	my $val = $chanconf{$_}{autojoin};
	my $skip = 0;

	if (defined $val) {
	    $skip++ if ($val eq "0");
	} else {
	    $skip++;
	}

	if ($skip) {
	    push(@skip, $_);
	    next;
	}

	push(@chans, $_);
    }

    if (scalar @skip) {
	&status("gJC: channels not auto-joining: @skip");
    } else {
	&status("gJC: auto-joining all chans.");
    }

    return @chans;
}

sub closeDCC {
    &DEBUG("closeDCC called.");

    foreach $type (keys %dcc) {
	next if ($type ne uc($type));
 
	foreach $nick (keys %{$dcc{$type}}) {
	    next unless (defined $nick);
	    &DEBUG("closing DCC $type to $nick (FIXME).");
	    next unless (defined $dcc{$type}{$nick});

	    $dcc{$type}{$nick}->close();
	}
    }
}

sub joinfloodCheck {
    my($who,$chan,$userhost) = @_;

    return unless (&IsChanConf("joinfloodCheck"));

    if (exists $netsplit{lc $who}) {	# netsplit join.
	&DEBUG("jfC: $who was in netsnipe; not checking.");
    }

    if (exists $floodjoin{$chan}{$who}{Time}) {
	&WARN("floodjoin{$chan}{$who} already exists?");
    }

    $floodjoin{$chan}{$who}{Time} = time();
    $floodjoin{$chan}{$who}{Host} = $userhost;

    ### Check...
    foreach (keys %floodjoin) {
	my $c = $_;
	my $count = scalar keys %{ $floodjoin{$c} };
	next unless ($count > 5);
	&DEBUG("count => $count");

	my $time;
	foreach (keys %{ $floodjoin{$c} }) {
	    $time += $floodjoin{$c}{$_}{Time};
	}
	&DEBUG("time => $time");
	$time /= $count;

	&DEBUG("new time => $time");
    }

    ### Clean it up.
    my $delete = 0;
    foreach $chan (keys %floodjoin) {
	foreach $who (keys %{ $floodjoin{$chan} }) {
	    my $time = time() - $floodjoin{$chan}{$who}{Time};
	    next unless ($time > 10);
	    delete $floodjoin{$chan}{$who};
	    $delete++;
	}
    }

    &DEBUG("jfC: $delete deleted.") if ($delete);
}

sub getHostMask {
    my($n) = @_;

    &FIXME("getHostMask...");
}

1;
