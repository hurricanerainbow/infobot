#
# User Command Extension Stubs
# WARN: this file does not reload on HUP.
#

#use strict;

$babel_lang_regex = "fr|sp|es|po|pt|it|ge|de|gr|en|zh|ja|jp|ko|kr|ru";

### COMMAND HOOK IMPLEMENTATION.
# addCmdHook("SECTION", 'TEXT_HOOK',
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
    my ($hashname, $ident, %hash) = @_;

    if (exists ${"hooks_$hashname"}{$ident}) {
###	&WARN("aCH: cmd hooks \%$hashname{$ident} already exists.");
	return;
    }

    &VERB("aCH: added $ident",2);	# use $hash{'Identifier'}?
    ### hrm... prevent warnings?
    ${"hooks_$hashname"}{$ident} = \%hash;
}

# RUN IF ADDRESSED.
sub parseCmdHook {
    my ($hashname, $line) = @_;
    $line =~ /^(\S+)( (.*))?$/;
    my $cmd	= $1;	# command name is whitespaceless.
    my $flatarg	= $3;
    my @args	= split(/\s+/, $flatarg || '');
    my $done	= 0;

    &shmFlush();

    if (!defined %{"hooks_$hashname"}) {
	&WARN("cmd hooks \%$hashname does not exist.");
	return 0;
    }

    if (!defined $cmd) {
	&WARN("cstubs: cmd == NULL.");
	return 0;
    }

    foreach (keys %{"hooks_$hashname"}) {
	# rename to something else! like $id or $label?
	my $ident = $_;

	next unless ($cmd =~ /^$ident$/i);

	if ($done) {
	    &WARN("pCH: Multiple hook match: $ident");
	    next;
	}

	&status("hooks($hashname): $cmd matched '$ident'");
	my %hash = %{ ${"hooks_$hashname"}{$ident} };

	if (!scalar keys %hash) {
	    &WARN("CmdHook: hash is NULL?");
	    return 1;
	}

	if ($hash{NoArgs} and $flatarg) {
	    &DEBUG("cmd $ident does not take args ('$flatarg'); skipping.");
	    next;
	}

	if (!exists $hash{CODEREF}) {
	    &ERROR("CODEREF undefined for $cmd or $ident.");
	    return 1;
	}

	### DEBUG.
	foreach (keys %hash) {
	    &VERB(" $cmd->$_ => '$hash{$_}'.",2);
	}

	### HELP.
	if (exists $hash{'Help'} and !scalar(@args)) {
	    &help( $hash{'Help'} );
	    return 1;
	}

	### IDENTIFIER.
	if (exists $hash{'Identifier'}) {
	    return 1 unless (&hasParam($hash{'Identifier'}));
	}

	### USER FLAGS.
	if (exists $hash{'UserFlag'}) {
	    return 1 unless (&hasFlag($hash{'UserFlag'}));
	}

	### FORKER,IDENTIFIER,CODEREF.
	if (exists $hash{'Forker'}) {
	    $hash{'Identifier'} .= "-" if ($hash{'Forker'} eq "NULL");

	    if (exists $hash{'ArrayArgs'}) {
		&Forker($hash{'Identifier'}, sub { \&{ $hash{'CODEREF'} }(@args) } );
	    } else {
		&Forker($hash{'Identifier'}, sub { \&{ $hash{'CODEREF'} }($flatarg) } );
	    }

	} else {
	    if (exists $hash{'Module'}) {
		&loadMyModule($myModules{ $hash{'Module'} });
	    }

	    # check if CODEREF exists.
	    if (!defined &{ $hash{'CODEREF'} }) {
		&WARN("coderef $hash{'CODEREF'} does not exist.");
		if (defined $who) {
		    &msg($who, "coderef does not exist for $ident.");
		}

		return 1;
	    }

	    if (exists $hash{'ArrayArgs'}) {
		&{ $hash{'CODEREF'} }(@args);
	    } else {
		&{ $hash{'CODEREF'} }($flatarg);
	    }
	}

	### CMDSTATS.
	if (exists $hash{'Cmdstats'}) {
	    $cmdstats{ $hash{'Cmdstats'} }++;
	}

	&VERB("hooks: End of command.",2);

	$done = 1;
    }

    return 1 if ($done);
    return 0;
}

###
### START ADDING HOOKS.
###
&addCmdHook("extra", 'd?bugs', ('CODEREF' => 'DBugs::Parse',
	'Forker' => 1, 'Identifier' => 'debianExtra',
	'Cmdstats' => 'Debian Bugs') );
&addCmdHook("extra", 'dauthor', ('CODEREF' => 'Debian::searchAuthor',
	'Forker' => 1, 'Identifier' => 'debian',
	'Cmdstats' => 'Debian Author Search', 'Help' => "dauthor" ) );
&addCmdHook("extra", '(d|search)desc', ('CODEREF' => 'Debian::searchDescFE',
	'Forker' => 1, 'Identifier' => 'debian',
	'Cmdstats' => 'Debian Desc Search', 'Help' => "ddesc" ) );
&addCmdHook("extra", 'dnew', ('CODEREF' => 'DebianNew',
	'Identifier' => 'debian' ) );
&addCmdHook("extra", 'dincoming', ('CODEREF' => 'Debian::generateIncoming',
	'Forker' => 1, 'Identifier' => 'debian' ) );
&addCmdHook("extra", 'dstats', ('CODEREF' => 'Debian::infoStats',
	'Forker' => 1, 'Identifier' => 'debian',
	'Cmdstats' => 'Debian Statistics' ) );
&addCmdHook("extra", 'd?contents', ('CODEREF' => 'Debian::searchContents',
	'Forker' => 1, 'Identifier' => 'debian',
	'Cmdstats' => 'Debian Contents Search', 'Help' => "contents" ) );
&addCmdHook("extra", 'd?find', ('CODEREF' => 'Debian::DebianFind',
	'Forker' => 1, 'Identifier' => 'debian',
	'Cmdstats' => 'Debian Search', 'Help' => "find" ) );
&addCmdHook("extra", 'insult', ('CODEREF' => 'Insult::Insult',
	'Forker' => 1, 'Identifier' => 'insult', 'Help' => "insult" ) );
&addCmdHook("extra", 'kernel', ('CODEREF' => 'Kernel::Kernel',
	'Forker' => 1, 'Identifier' => 'kernel',
	'Cmdstats' => 'Kernel', 'NoArgs' => 1) );
&addCmdHook("extra", 'listauth', ('CODEREF' => 'CmdListAuth',
	'Identifier' => 'search', Module => 'factoids', 
	'Help' => 'listauth') );
&addCmdHook("extra", 'quote', ('CODEREF' => 'Quote::Quote',
	'Forker' => 1, 'Identifier' => 'quote',
	'Help' => 'quote', 'Cmdstats' => 'Quote') );
&addCmdHook("extra", 'countdown', ('CODEREF' => 'Countdown',
	'Module' => 'countdown', 'Identifier' => 'countdown',
	'Cmdstats' => 'Countdown') );
&addCmdHook("extra", 'lart', ('CODEREF' => 'lart',
	'Identifier' => 'lart', 'Help' => 'lart') );
&addCmdHook("extra", 'convert', ('CODEREF' => 'convert',
	'Forker' => 1, 'Identifier' => 'units',
	'Help' => 'convert') );
&addCmdHook("extra", '(cookie|random)', ('CODEREF' => 'cookie',
	'Forker' => 1, 'Identifier' => 'factoids') );
&addCmdHook("extra", 'u(ser)?info', ('CODEREF' => 'userinfo',
	'Identifier' => 'userinfo', 'Help' => 'userinfo',
	'Module' => 'userinfo') );
&addCmdHook("extra", 'rootWarn', ('CODEREF' => 'CmdrootWarn',
	'Identifier' => 'rootWarn', 'Module' => 'rootwarn') );
&addCmdHook("extra", 'seen', ('CODEREF' => 'seen', 'Identifier' =>
	'seen') );
&addCmdHook("extra", 'dict', ('CODEREF' => 'Dict::Dict',
	'Identifier' => 'dict', 'Help' => 'dict',
	'Forker' => 1, 'Cmdstats' => 'Dict') );
&addCmdHook("extra", 'slashdot', ('CODEREF' => 'Slashdot::Slashdot',
	'Identifier' => 'slashdot', 'Forker' => 1,
	'Cmdstats' => 'Slashdot') );
&addCmdHook("extra", 'plug', ('CODEREF' => 'Plug::Plug',
	'Identifier' => 'plug', 'Forker' => 1,
	'Cmdstats' => 'Plug') );
&addCmdHook("extra", 'uptime', ('CODEREF' => 'uptime', 'Identifier' => 'uptime',
	'Cmdstats' => 'Uptime') );
&addCmdHook("extra", 'nullski', ('CODEREF' => 'nullski', ) );
&addCmdHook("extra", '(fm|freshmeat)', ('CODEREF' => 'Freshmeat::Freshmeat',
	'Identifier' => 'freshmeat', 'Cmdstats' => 'Freshmeat',
	'Forker' => 1, 'Help' => 'freshmeat') );
&addCmdHook("extra", 'verstats', ('CODEREF' => 'do_verstats' ) );
&addCmdHook("extra", 'weather', ('CODEREF' => 'Weather::Weather',
	'Identifier' => 'weather', 'Help' => 'weather',
	'Cmdstats' => 'weather', 'Forker' => 1) );
&addCmdHook("extra", 'bzflist', ('CODEREF' => 'BZFlag::list',
	'Identifier' => 'bzflag', 'Cmdstats' => 'BZFlag',
	'Forker' => 1) );
&addCmdHook("extra", 'bzfquery', ('CODEREF' => 'BZFlag::query',
	'Identifier' => 'bzflag', 'Cmdstats' => 'BZFlag',
	'Forker' => 1, 'Help' => 'bzflag') );
&addCmdHook("extra", 'zfi', ('CODEREF' => 'zfi::query',
	'Identifier' => 'zfi', 'Cmdstats' => 'zfi',
	'Forker' => 1) );
&addCmdHook("extra", '(zippy|yow)', ('CODEREF' => 'zippy::get',
	'Identifier' => 'zippy', 'Cmdstats' => 'zippy',
	'Forker' => 1) );
&addCmdHook("extra", 'zsi', ('CODEREF' => 'zsi::query',
	'Identifier' => 'zsi', 'Cmdstats' => 'zsi',
	'Forker' => 1) );
&addCmdHook("extra", '(ex)?change', ('CODEREF' => 'Exchange::query',
	'Identifier' => 'exchange', 'Cmdstats' => 'exchange',
	'Forker' => 1) );

###
### END OF ADDING HOOKS.
###
&status("CMD: loaded ".scalar(keys %hooks_extra)." EXTRA command hooks.");

sub Modules {
    if (!defined $message) {
	&WARN("Modules: message is undefined. should never happen.");
	return;
    }

    # babel bot: Jonathan Feinberg++
    if ($message =~ m{
		^\s*
		(?:babel(?:fish)?|x|xlate|translate)
		\s+
		($babel_lang_regex)\w*	# from language?
		\s+
		($babel_lang_regex)\w*	# to language?
		\s*
		(.+)			# The phrase to be translated
    }xoi) {
	return unless (&hasParam("babelfish"));

	&Forker("babelfish", sub { &babel::babelfish(lc $1, lc $2, $3); } );

	$cmdstats{'BabelFish'}++;
	return;
    }

    my $debiancmd	 = 'conflicts?|depends?|desc|file|info|provides?';
    $debiancmd		.= '|recommends?|suggests?|maint|maintainer';

    if ($message =~ /^($debiancmd)(\s+(.*))?$/i) {
	return unless (&hasParam("debian"));
	my $package = lc $3;

	if (defined $package) {
	    &Forker("debian", sub { &Debian::infoPackages($1, $package); } );
	} else {
	    &help($1);
	}

	return;
    }

    # google searching. Simon++
    if ($message =~ /^(?:search\s+)?(\S+)\s+for\s+['"]?(.*?)["']?\s*\?*$/i) {
	return unless (&hasParam("wwwsearch"));

	&Forker("wwwsearch", sub { &W3Search::W3Search($1,$2); } );

	$cmdstats{'WWWSearch'}++;
	return;
    }

    # text counters. (eg: hehstats)
    my $itc;
    $itc = &getChanConf("ircTextCounters");
    $itc = &findChanConf("ircTextCounters") unless ($itc);
    if ($itc) {
	$itc =~ s/([^\w\s])/\\$1/g;
	my $z = join '|', split ' ', $itc;

	if ($msgType eq "privmsg" and $message =~ / ($mask{chan})$/) {
	    &DEBUG("ircTC: privmsg detected; chan = $1");
	    $chan = $1;
	}

	if ($message =~ /^_stats(\s+(\S+))$/i) {
	    &textstats_main($2);
	    return;
	}

	if ($message =~ /^($z)stats(\s+(\S+))?$/i) {
	    my $type	= $1;
	    my $arg	= $3;

	    # even more uglier with channel/time arguments.
	    my $c	= $chan;
#	    my $c	= $chan || "PRIVATE";
	    my $where	= "type=".&dbQuote($type);
	    $where	.= " AND channel=".&dbQuote($c) if (defined $c);
	    &DEBUG("not using chan arg") if (!defined $c);
	    my $sum = (&dbRawReturn("SELECT SUM(counter) FROM stats"
			." WHERE ".$where ))[0];

	    if (!defined $arg or $arg =~ /^\s*$/) {
		# this is way fucking ugly.

		my %hash = &dbGetCol("stats", "nick,counter",
			$where." ORDER BY counter DESC LIMIT 3", 1);
		my $i;
		my @top;

		# unfortunately we have to sort it again!
		# todo: make dbGetCol return hash and array? too much effort.
		my $tp = 0;
		foreach $i (sort { $b <=> $a } keys %hash) {
		    foreach (keys %{ $hash{$i} }) {
			my $p	= sprintf("%.01f", 100*$i/$sum);
			$tp	+= $p;
			push(@top, "\002$_\002 -- $i ($p%)");
		    }
		}
		my $topstr = "";
		&DEBUG("*stats: tp => $tp");
		if (scalar @top) {
		    $topstr = ".  Top ".scalar(@top).": ".join(', ', @top);
		}

		if (defined $sum) {
		    &pSReply("total count of \037$type\037 on \002$c\002: $sum$topstr");
		} else {
		    &pSReply("zero counter for \037$type\037.");
		}
	    } else {
		my $x = (&dbRawReturn("SELECT SUM(counter) FROM stats".
			" WHERE $where AND nick=".&dbQuote($arg) ))[0];

		if (!defined $x) {	# !defined.
		    &pSReply("$arg has not said $type yet.");
		    return;
		}

		# defined.
		my @array = &dbGet("stats", "nick",
			$where." ORDER BY counter", 1);
		my $good = 0;
		my $i = 0;
		for($i=0; $i<scalar @array; $i++) {
		    next unless ($array[0] =~ /^\Q$who\E$/);
		    $good++;
		    last;
		}
		$i++;

		my $total = scalar(@array);
		my $xtra = "";
		if ($total and $good) {
		    my $pct = sprintf("%.01f", 100*(1+$total-$i)/$total);
		    $xtra = ", ranked $i\002/\002$total (percentile: \002$pct\002 %)";
		}

		my $pct1 = sprintf("%.01f", 100*$x/$sum);
		&pSReply("\002$arg\002 has said \037$type\037 \002$x\002 times (\002$pct1\002 %)$xtra");
	    }

	    return;
	}

	if ($@) {
	    &DEBUG("regex failed: $@");
	    return;
	}
    }

    # list{keys|values}. xk++. Idea taken from #linuxwarez@EFNET
    if ($message =~ /^list(\S+)(\s+(.*))?$/i) {
	return unless (&hasParam("search"));

	my $thiscmd	= lc $1;
	my $args	= $3 || "";

	$thiscmd	=~ s/^vals$/values/;
#	$args		=~ s/\s+$//g;
	return if ($thiscmd ne "keys" && $thiscmd ne "values");

	# Usage:
	if (!defined $args or $args =~ /^\s*$/) {
	    &help("list". $thiscmd);
	    return;
	}

	# suggested by asuffield and \broken.
	if ($args =~ /^["']/ and $args =~ /["']$/) {
	    &DEBUG("list*: removed quotes.");
	    $args	=~ s/^["']|["']$//g;
	}

	if (length $args == 1) {
	    &msg($who,"search string is too short.");
	    return;
	}

	&Forker("search", sub { &Search::Search($thiscmd, $args); } );

	$cmdstats{'Factoid Search'}++;
	return;
    }

    # Nickometer. Adam Spiers++
    if ($message =~ /^(?:lame|nick)ometer(?: for)? (\S+)/i) {
	return unless (&hasParam("nickometer"));

	my $term = (lc $1 eq 'me') ? $who : $1;

	&loadMyModule($myModules{'nickometer'});

	if ($term =~ /^$mask{chan}$/) {
	    &status("Doing nickometer for chan $term.");

	    if (!&validChan($term)) {
		&msg($who, "error: channel is invalid.");
		return;
	    }

	    # step 1.
	    my %nickometer;
	    foreach (keys %{ $channels{lc $term}{''} }) {
		my $str   = $_;
		if (!defined $str) {
		    &WARN("nickometer: nick in chan $term undefined?");
		    next;
		}

		my $value = &nickometer($str);
		$nickometer{$value}{$str} = 1;
	    }

	    # step 2.
	    ### TODO: compact with map?
	    my @list;
	    foreach (sort {$b <=> $a} keys %nickometer) {
		my $str = join(", ", sort keys %{ $nickometer{$_} });
		push(@list, "$str ($_%)");
	    }

	    &pSReply( &formListReply(0, "Nickometer list for $term ", @list) );
	    &DEBUG("test.");

	    return;
	}

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

	return;
    }

    # Topic management. xk++
    # may want to add a userflags for topic. -xk
    if ($message =~ /^topic(\s+(.*))?$/i) {
	return unless (&hasParam("topic"));

	my $chan	= $talkchannel;
	my @args	= split / /, $2 || "";

	if (!scalar @args) {
	    &msg($who,"Try 'help topic'");
	    return;
	}

	$chan		= lc(shift @args) if ($msgType eq 'private');
	my $thiscmd	= shift @args;

	# topic over public:
	if ($msgType eq 'public' && $thiscmd =~ /^#/) {
	    &msg($who, "error: channel argument is not required.");
	    &msg($who, "\002Usage\002: topic <CMD>");
	    return;
	}

	# topic over private:
	if ($msgType eq 'private' && $chan !~ /^#/) {
	    &msg($who, "error: channel argument is required.");
	    &msg($who, "\002Usage\002: topic #channel <CMD>");
	    return;
	}

	if (&validChan($chan) == 0) {
	    &msg($who,"error: invalid channel \002$chan\002");
	    return;
	}

	# for semi-outsiders.
	if (!&IsNickInChan($who,$chan)) {
	    &msg($who, "Failed. You ($who) are not in $chan, hey?");
	    return;
	}

	# now lets do it.
	&loadMyModule($myModules{'topic'});
	&Topic($chan, $thiscmd, join(' ', @args));
	$cmdstats{'Topic'}++;
	return;
    }

    # wingate.
    if ($message =~ /^wingate$/i) {
	return unless (&hasParam("wingate"));

	my $reply = "Wingate statistics: scanned \002"
			.scalar(keys %wingate)."\002 hosts";
	my $queue = scalar(keys %wingateToDo);
	if ($queue) {
	    $reply .= ".  I have \002$queue\002 hosts in the queue";
	    $reply .= ".  Started the scan ".&Time2String(time() - $wingaterun)." ago";
	}

	&pSReply("$reply.");

	return;
    }

    # do nothing and let the other routines have a go
    return "CONTINUE";
}

# Freshmeat. xk++
sub freshmeat {
    my ($query) = @_;

    if (!defined $query) {
	&help("freshmeat");
	&msg($who, "I have \002".&countKeys("freshmeat")."\002 entries.");
	return;
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
    my($person) = lc shift;
    $person =~ s/\?*$//;

    if (!defined $person or $person =~ /^$/) {
	&help("seen");

	my $i = &countKeys("seen");
	&msg($who,"there ". &fixPlural("is",$i) ." \002$i\002 ".
		"seen ". &fixPlural("entry",$i) ." that I know of.");

	return;
    }

    my @seen;

    &seenFlush();	# very evil hack. oh well, better safe than sorry.

    ### TODO: Support &dbGetColInfo(); like in &FactInfo();
    my $select = "nick,time,channel,host,message";
    if ($person eq "random") {
	@seen = &randKey("seen", $select);
    } else {
	@seen = &dbGet("seen", $select, "nick=".&dbQuote($person) );
    }

    if (scalar @seen < 2) {
	foreach (@seen) {
	    &DEBUG("seen: _ => '$_'.");
	}
	&performReply("i haven't seen '$person'");
	return;
    }

    # valid seen.
    my $reply;
    ### TODO: multi channel support. may require &IsNick() to return
    ###	all channels or something.
    my @chans = &getNickInChans($seen[0]);
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

    &pSReply($reply);
    return;
}

# User Information Services. requested by Flugh.
sub userinfo {
    my ($arg) = join(' ',@_);

    if ($arg =~ /^set(\s+(.*))?$/i) {
	$arg = $2;
	if (!defined $arg) {
	    &help("userinfo set");
	    return;
	}

	&UserInfoSet(split /\s+/, $arg, 2);
    } elsif ($arg =~ /^unset(\s+(.*))?$/i) {
	$arg = $2;
	if (!defined $arg) {
	    &help("userinfo unset");
	    return;
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
    my $cookiemsg	= &getRandom(keys %{ $lang{'cookie'} });
    my ($key,$value);

    ### WILL CHEW TONS OF MEM.
    ### TODO: convert this to a Forker function!
    if ($arg) {
	my @list = &searchTable("factoids", "factoid_key", "factoid_value", $arg);
	$key  = &getRandom(@list);
	$value  = &getFactInfo($key, "factoid_value");
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
    my $arg = join(' ',@_);
    my ($from,$to) = ('','');

    ($from,$to) = ($1,$2) if ($arg =~ /^(.*?) to (.*)$/i);
    ($from,$to) = ($2,$1) if ($arg =~ /^(.*?) from (.*)$/i);

    if (!$to or !$from) {
	&msg($who, "Invalid format!");
	&help("convert");
	return;
    }

    &Units::convertUnits($from, $to);

    return;
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
	    return;
	}
    }

    my $line = &getRandomLineFromFile($bot_data_dir. "/blootbot.lart");
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

sub DebianNew {
    my $idx   = "debian/Packages-sid.idx";
    my $error = 0;
    my %pkg;
    my @new;

    $error++ unless ( -e $idx);
    $error++ unless ( -e "$idx-old");

    if ($error) {
	$error = "no sid/sid-old index file found.";
	&ERROR("Debian: $error");
	&msg($who, $error);
	return;
    }

    open(IDX1, $idx);
    open(IDX2, "$idx-old");

    while (<IDX2>) {
	chop;
	next if (/^\*/);

	$pkg{$_} = 1;
    }
    close IDX2;

    open(IDX1,$idx);
    while (<IDX1>) {
	chop;
	next if (/^\*/);
	next if (exists $pkg{$_});

	push(@new, $_);
    }
    close IDX1;

    &::pSReply( &::formListReply(0, "New debian packages:", @new) );
}

sub do_verstats {
    my ($chan)	= @_;

    if (!defined $chan) {
	&help("verstats");
	return;
    }

    if (!&validChan($chan)) {
	&msg($who, "chan $chan is invalid.");
	return;
    }

    if (scalar @vernick > scalar(keys %{ $channels{lc $chan}{''} })/4) {
	&msg($who, "verstats already in progress for someone else.");
	return;
    }

    &msg($who, "Sending CTCP VERSION to #$chan...");
    $conn->ctcp("VERSION", $chan);
    $cache{verstats}{chan}	= $chan;
    $cache{verstats}{who}	= $who;
    $cache{verstats}{msgType}	= $msgType;

    $conn->schedule(30, sub {
	my $c		= lc $cache{verstats}{chan};
	@vernicktodo	= ();

	foreach (keys %{ $channels{$c}{''} } ) {
	    next if (grep /^\Q$_\E$/i, @vernick);
	    push(@vernicktodo, $_);
	}

	&verstats_flush();
    } );

    $conn->schedule(60, sub {
	my $vtotal	= 0;
	my $c		= lc $cache{verstats}{chan};
	my $total	= keys %{ $channels{$c}{''} };
	$chan		= $c;
	$who		= $cache{verstats}{who};
	$msgType	= $cache{verstats}{msgType};
	delete $cache{verstats};	# sufficient?

	foreach (keys %ver) {
	    $vtotal	+= scalar keys %{ $ver{$_} };
	}

	my %sorted;
	my $unknown	= $total - $vtotal;
	my $perc	= sprintf("%.1f", $unknown * 100 / $total);
	$perc		=~ s/.0$//;
	$sorted{$perc}{"unknown/cloak"} = "$unknown ($perc%)" if ($unknown);

	foreach (keys %ver) {
	    my $count	= scalar keys %{ $ver{$_} };
	    $perc	= sprintf("%.01f", $count * 100 / $total);
	    $perc	=~ s/.0$//;	# lame compression.

	    $sorted{$perc}{$_} = "$count ($perc%)";
	}

	### can be compressed to a map?
	my @list;
	foreach ( sort { $b <=> $a } keys %sorted ) {
	    my $perc = $_;
	    foreach (sort keys %{ $sorted{$perc} }) {
		push(@list, "$_ - $sorted{$perc}{$_}");
	    }
	}

	&pSReply( &formListReply(0, "IRC Client versions for $c ", @list) );

	# clean up not-needed data structures.
	undef %ver;
	undef @vernick;
    } );

    return;
}

sub verstats_flush {
    for (1..5) {
	last unless (scalar @vernicktodo);

	my $n = shift(@vernicktodo);
	$conn->ctcp("VERSION", $n);
    }

    return unless (scalar @vernicktodo);

    $conn->schedule(3, \&verstats_flush() );
}

sub textstats_main {
    my($arg) = @_;

    # even more uglier with channel/time arguments.
    my $c	= $chan;
#    my $c	= $chan || "PRIVATE";
    my $where	= "channel=".&dbQuote($c) if (defined $c);
    &DEBUG("not using chan arg") if (!defined $c);
    my $sum = (&dbRawReturn("SELECT SUM(counter) FROM stats"
		." WHERE ".$where ))[0];

    if (!defined $arg or $arg =~ /^\s*$/) {
	# this is way fucking ugly.
	&DEBUG("_stats: !arg");

	my %hash = &dbGetCol("stats", "nick,counter",
		$where." ORDER BY counter DESC LIMIT 3", 1);
	my $i;
	my @top;

	# unfortunately we have to sort it again!
	# todo: make dbGetCol return hash and array? too much effort.
	my $tp = 0;
	foreach $i (sort { $b <=> $a } keys %hash) {
	    foreach (keys %{ $hash{$i} }) {
		my $p	= sprintf("%.01f", 100*$i/$sum);
		$tp	+= $p;
		push(@top, "\002$_\002 -- $i ($p%)");
	    }
	}

	my $topstr = "";
	&DEBUG("*stats: tp => $tp");
	if (scalar @top) {
	    $topstr = ".  Top ".scalar(@top).": ".join(', ', @top);
	}

	if (defined $sum) {
	    &pSReply("total count of \037$type\037 on \002$c\002: $sum$topstr");
	} else {
	    &pSReply("zero counter for \037$type\037.");
	}
    } else {
	my %hash = &dbGetCol("stats", "type,counter",
		"$where AND nick=".&dbQuote($arg) );

	foreach (keys %hash) {
	    &DEBUG("_stats: hash{$_} => $hash{$_}");
	    # ranking.
	    my @array = &dbGet("stats", "nick",
		$where." ORDER BY counter", 1);
	    my $good = 0;
	    my $i = 0;
	    for($i=0; $i<scalar @array; $i++) {
		next unless ($array[0] =~ /^\Q$who\E$/);
		$good++;
		last;
	    }
	    $i++;

	    my $total = scalar(@array);
	    &DEBUG("   i => $i, good => $good, total => $total");
	}

	return;

	if (!defined $x) {	# !defined.
	    &pSReply("$arg has not said $type yet.");
	    return;
	}

	my $xtra = "";
	if ($total and $good) {
	    my $pct = sprintf("%.01f", 100*(1+$total-$i)/$total);
	    $xtra = ", ranked $i\002/\002$total (percentile: \002$pct\002 %)";
	}

	my $pct1 = sprintf("%.01f", 100*$x/$sum);
	&pSReply("\002$arg\002 has said \037$type\037 \002$x\002 times (\002$pct1\002 %)$xtra");
    }
}

sub nullski { my ($arg) = @_; return unless (defined $arg);
	foreach (`$arg`) { &msg($who,$_); } }

1;
