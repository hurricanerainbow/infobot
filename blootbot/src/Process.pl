###
### Process.pl: Kevin Lenzo 1997-1999
###

#
# process the incoming message
#

if (&IsParam("useStrict")) { use strict; }

sub process {
    $learnok	= 0;	# Able to learn?
    $talkok	= 0;	# Able to yap?
    $force_public_reply = 0;
    $literal	= 0;

    return 'X'			if $who eq $ident;	# self-message.
    return 'addressedother set' if ($addressedother);

    $talkok	= ($param{'addressing'} =~ /^OPTIONAL$/i or $addressed);
    $learnok	= ($param{'learn'}      =~ /^HUNGRY$/i   or $addressed);

    &shmFlush();		# hack.

    # check if we have our head intact.
    if ($lobotomized) {
	if ($addressed and IsFlag("o") eq "o") {
	    my $delta_time	= time() - ($cache{lobotomy}{$who} || 0);
	    &msg($who, "give me an unlobotomy.") if ($delta_time > 60*60);
	    $cache{lobotomy}{$who} = time();
	}
	return 'LOBOTOMY';
    }

    # talkMethod.
    if ($param{'talkMethod'} =~ /^PRIVATE$/i) {
	if ($msgType =~ /public/ and $addressed) {
	    &msg($who, "sorry. i'm in 'PRIVATE' talkMethod mode ".
		  "while you sent a message to me ${msgType}ly.");

	    return 'TALKMETHOD';
	}
    }

    # join, must be done before outsider checking.
    if ($message =~ /^join(\s+(.*))?\s*$/i) {
	return 'join: not addr' unless ($addressed);

	$2 =~ /^($mask{chan})(,(\S+))?/;
	my($thischan, $key) = (lc $1, $3);
	my $chankey	= lc $thischan;
	$chankey	.= " $key"	if (defined $key);

	if ($thischan eq "") {
	    &help("join");
	    return;
	}

	if (&IsFlag("o") ne "o") {
	    if (!exists $chanconf{$thischan}) {
		&msg($who, "I am not allowed to join $thischan.");
		return;
	    }

	    if (&validChan($thischan)) {
		&msg($who,"warn: I'm already on $thischan, joining  anyway...");
#		return;
	    }
	}
	$cache{join}{$thischan} = $who;	# used for on_join self.

	&joinchan($chankey);
	&status("JOIN $chankey <$who>");
	&msg($who, "joining $chankey");

	return;
    }

    # 'identify'
    if ($msgType =~ /private/ and $message =~ s/^identify//i) {
	$message =~ s/^\s+|\s+$//g;
	my @array = split / /, $message;

	if ($who =~ /^_default$/i) {
	    &pSReply("you are too eleet.");
	    return;
	}

	if (!scalar @array or scalar @array > 2) {
	    &help("identify");
	    return;
	}

	my $do_nick = $array[1] || $who;

	if (!exists $users{$do_nick}) {
	    &pSReply("nick $do_nick is not in user list.");
	    return;
	}

	my $crypt = $users{$do_nick}{PASS};
	if (!defined $crypt) {
	    &pSReply("user $do_nick has no passwd set.");
	    return;
	}

	if (!&ckpasswd($array[0], $crypt)) {
	    &pSReply("invalid passwd for $do_nick.");
	    return;
	}

	my $mask = "*!$user@".&makeHostMask($host);
	### TODO: prevent adding multiple dupe masks?
	### TODO: make &addHostMask() CMD?
	&pSReply("Added $mask for $do_nick...");
	$users{$do_nick}{HOSTS}{$mask} = 1;

	return;
    }

    # 'pass'
    if ($msgType =~ /private/ and $message =~ s/^pass//i) {
	$message =~ s/^\s+|\s+$//g;
	my @array = split ' ', $message;

	if ($who =~ /^_default$/i) {
	    &pSReply("you are too eleet.");
	    return;
	}

	if (scalar @array != 1) {
	    &help("pass");
	    return;
	}

	# todo: use &getUser()?
	my $first	= 1;
	foreach (keys %users) {
	    if ($users{$_}{FLAGS} =~ /n/) {
		$first = 0;
		last;
	    }
	}

	if (!exists $users{$who} and !$first) {
	    &pSReply("nick $who is not in user list.");
	    return;
	}

	if ($first) {
	    &pSReply("First time user... adding you as Master.");
	    $users{$who}{FLAGS} = "mrsteon";
	}

	my $crypt = $users{$who}{PASS};
	if (defined $crypt) {
	    &pSReply("user $who already has pass set.");
	    return;
	}

	if (!defined $host) {
	    &WARN("pass: host == NULL.");
	    return;
	}

	if (!scalar keys %{ $users{$who}{HOSTS} }) {
	    my $mask = "*!$user@".&makeHostMask($host);
	    &pSReply("Added hostmask '\002$mask\002' to $who");
	    $users{$who}{HOSTS}{$mask}	= 1;
	}

	$crypt			= &mkcrypt($array[0]);
	$users{$who}{PASS}	= $crypt;
	&pSReply("new pass for $who, crypt $crypt.");

	return;
    }

    # allowOutsiders.
    if (&IsParam("disallowOutsiders") and $msgType =~ /private/i) {
	my $found = 0;

	foreach (keys %channels) {
	    next unless (&IsNickInChan($who,$_));

	    $found++;
	    last;
	}

	if (!$found and scalar(keys %channels)) {
	    &status("OUTSIDER <$who> $message");
	    return 'OUTSIDER';
	}
    }

    # override msgType.
    if ($msgType =~ /public/ and $message =~ s/^\+//) {
	&status("Process: '+' flag detected; changing reply to public");
	$msgType = 'public';
	$who	 = $chan;	# major hack to fix &msg().
	$force_public_reply++;
	# notice is still NOTICE but to whole channel => good.
    }

    # User Processing, for all users.
    if ($addressed) {
	my $retval;
	return 'returned from pCH'   if &parseCmdHook("main",$message);

	$retval	= &userCommands();
	return unless (defined $retval);
	return if ($retval eq $noreply);
    }

    ###
    # once useless messages have been parsed out, we match them.
    ###

    # confused? is this for infobot communications?
    foreach (keys %{ $lang{'confused'} }) {
	my $y = $_;

	next unless ($message =~ /^\Q$y\E\s*/);
	return 'CONFUSO';
    }

    # hello. [took me a while to fix this. -xk]
    if ($orig{message} =~ /^(\Q$ident\E\S?[:, ]\S?)?\s*(h(ello|i( there)?|owdy|ey|ola))( \Q$ident\E)?\s*$/i) {
	return '' unless ($talkok);

	# 'mynick: hi' or 'hi mynick' or 'hi'.
	&status("somebody said hello");

	# 50% chance of replying to a random greeting when not addressed
	if (!defined $5 and $addressed == 0 and rand() < 0.5) {
	    &status("not returning unaddressed greeting");
	    return;
	}

	# customized random message.
	my $tmp = (rand() < 0.5) ? ", $who" : "";
	&performStrictReply(&getRandom(keys %{ $lang{'hello'} }) . $tmp);
	return;
    }

    # greetings.
    if ($message =~ /how (the hell )?are (ya|you)( doin\'?g?)?\?*$/) {
	my $reply = &getRandom(keys %{ $lang{'howareyou'} });

	&performReply($reply);
        
	return;
    }

    # praise.
    if ($message =~ /you (rock|rewl|rule|are so+ coo+l)/ ||
	$message =~ /(good (bo(t|y)|g([ui]|r+)rl))|(bot( |\-)?snack)/i)
    {
	return 'praise: no addr' unless ($addressed);

	&status("random praise detected");

	my $tmp = (rand() < 0.5) ? "thanks $who " : "";
	&performStrictReply($tmp.":)");

	return;
    }

    # thanks.
    if ($message =~ /^than(ks?|x)( you)?( \S+)?/i) {
	return 'thank: no addr' unless ($message =~ /$ident/ or $talkok);

	&performReply( &getRandom(keys %{ $lang{'welcome'} }) );
	return;
    }

    ###
    ### bot commands...
    ###

    # karma. set...
    if ($message =~ /^(\S+)(--|\+\+)\s*$/ and $addressed) {
	return '' unless (&hasParam("karma"));

	my($term,$inc) = (lc $1,$2);

	if ($msgType !~ /public/i) {
	    &msg($who, "karma must be done in public!");
	    return;
	}

	if (lc $term eq lc $who) {
	    &msg($who, "please don't karma yourself");
	    return;
	}

	my $karma = &dbGet("stats", "counter", "nick='$term' and type='karma'") || 0;
	if ($inc eq '++') {
	    $karma++;
	} else {
	    $karma--;
	}

	&dbSet("stats", 
		{ nick => $term, type => "karma" },
		{ counter => $karma }
	);

	return;
    }

    # here's where the external routines get called.
    # if they return anything but null, that's the "answer".
    if ($addressed) {
	if ( &parseCmdHook("extra",$message) ) {
	    return 'DID SOMETHING IN PCH.';
	}

	my $er = &Modules();
	if (!defined $er) {
	    return 'SOMETHING 1';
	}

	if (0 and $addrchar) {
	    &msg($who, "I don't trust people to use the core commands while addressing me in a short-cut way.");
	    return;
	}
    }

    if (&IsParam("factoids") and $param{'DBType'} =~ /^(mysql|pg|postgres|dbm)/i) {
	&FactoidStuff();
    } elsif ($param{'DBType'} =~ /^none$/i) {
	return "NO FACTOIDS.";
    } else {
	&ERROR("INVALID FACTOID SUPPORT? ($param{'DBType'})");
	&shutdown();
	exit 0;
    }
}

sub FactoidStuff {
    # inter-infobot.
    if ($msgType =~ /private/ and $message =~ s/^:INFOBOT://) {
	### identification.
	&status("infobot <$nuh> identified") unless $bots{$nuh};
	$bots{$nuh} = $who;

	### communication.

	# query.
	if ($message =~ /^QUERY (<.*?>) (.*)/) {	# query.
	    my ($target,$item) = ($1,$2);
	    $item =~ s/[.\?]$//;

	    &status(":INFOBOT:QUERY $who: $message");

	    if ($_ = &getFactoid($item)) {
		&msg($who, ":INFOBOT:REPLY $target $item =is=> $_");
	    }

	    return 'INFOBOT QUERY';
	} elsif ($message =~ /^REPLY <(.*?)> (.*)/) {	# reply.
	    my ($target,$item) = ($1,$2);

	    &status(":INFOBOT:REPLY $who: $message");

	    my ($lhs,$mhs,$rhs) = $item =~ /^(.*?) =(.*?)=> (.*)/;

	    if ($param{'acceptUrl'} !~ /REQUIRE/ or $rhs =~ /(http|ftp|mailto|telnet|file):/) {
		&msg($target, "$who knew: $lhs $mhs $rhs");

		# "are" hack :)
		$rhs = "<REPLY> are" if ($mhs eq "are");
		&setFactInfo($lhs, "factoid_value", $rhs);
	    }

	    return 'INFOBOT REPLY';
	} else {
	    &ERROR(":INFOBOT:UNKNOWN $who: $message");
	    return 'INFOBOT UNKNOWN';
	}
    }

    # factoid forget.
    if ($message =~ s/^forget\s+//i) {
	return 'forget: no addr' unless ($addressed);

	my $faqtoid = $message;
	if ($faqtoid eq "") {
	    &help("forget");
	    return;
	}

	$faqtoid =~ tr/A-Z/a-z/;
	my $result = &getFactoid($faqtoid);

	if (defined $result) {
	    my $author	= &getFactInfo($faqtoid, "created_by");
	    my $count	= &getFactInfo($faqtoid, "requested_count") || 0;
	    my $limit	= &getChanConfDefault("factoidPreventForgetLimit", 
				0, $chan);

	    if (IsFlag("r") ne "r") {
		&msg($who, "you don't have access to remove factoids");
		return;
	    }

	    return 'locked factoid' if (&IsLocked($faqtoid) == 1);

	    # factoidPreventForgetLimit:
	    if ($limit and $count > $limit and (&IsFlag("o") ne "o")) {
		&msg($who, "will not delete '$faqtoid', count > limit ($count > $limit)");
		return;
	    }

	    if (&IsParam("factoidDeleteDelay") or &IsChanConf("factoidDeleteDelay")) {
		if ($faqtoid =~ / #DEL#$/ and !&IsFlag("o")) {
		    &msg($who, "cannot delete it ($faqtoid).");
		    return;
		}

		&status("forgot (safe delete): <$who> '$faqtoid' =is=> '$result'");
		### TODO: check if the "backup" exists and overwrite it
		my $check = &getFactoid("$faqtoid #DEL#");

		if (!defined $check or $check =~ /^\s*$/) {
		    if ($faqtoid !~ / #DEL#$/) {
			my $new = $faqtoid." #DEL#";
			&DEBUG("Process: backing up $faqtoid to '$new'.");

			# this looks weird but does it work?
			&setFactInfo($faqtoid, "factoid_key", $new);
			&setFactInfo($new, "modified_by", $who);
			&setFactInfo($new, "modified_time", time());

		    } else {
			&status("not backing up $faqtoid.");
		    }

		} else {
		    &status("forget: not overwriting backup!");
		}

	    } else {
		&status("forget: <$who> '$faqtoid' =is=> '$result'");
	    }
	    &delFactoid($faqtoid);

	    &performReply("i forgot $faqtoid");

	    $count{'Update'}++;
	} else {
	    &performReply("i didn't have anything called '$faqtoid'");
	}

	return;
    }

    # factoid unforget/undelete.
    if ($message =~ s/^un(forget|delete)\s+//i) {
	return 'unforget: no addr' unless ($addressed);

	my $i = 0;
	$i++ if (&IsParam("factoidDeleteDelay"));
	$i++ if (&IsChanConf("factoidDeleteDelay"));
	if (!$i) {
	    &performReply("safe delete has been disable so what is there to undelete?");
	    return;
	}

	my $faqtoid = $message;
	if ($faqtoid eq "") {
	    &help("undelete");
	    return;
	}

	$faqtoid =~ tr/A-Z/a-z/;
	my $result = &getFactoid($faqtoid." #DEL#");
	my $check  = &getFactoid($faqtoid);

	if (!defined $result) {
	    &performReply("i didn't have anything ('$faqtoid') to undelete.");
	    return;
	}

	if (defined $check) {
	    &performReply("cannot undeleted '$faqtoid' because it already exists?");
	    return;
	}

	&setFactInfo($faqtoid." #DEL#", "factoid_key", $faqtoid);

	### delete info. modified_ isn't really used.
	&setFactInfo($faqtoid, "modified_by",  "");
	&setFactInfo($faqtoid, "modified_time", 0);

	&performReply("Successfully recovered '$faqtoid'.  Have fun now.");

	$count{'Undelete'}++;

	return;
    }

    # factoid locking.
    if ($message =~ /^((un)?lock)(\s+(.*))?\s*?$/i) {
	return 'lock: no addr 2' unless ($addressed);

	my $function = lc $1;
	my $faqtoid  = lc $4;

	if ($faqtoid eq "") {
	    &help($function);
	    return;
	}

	if (&getFactoid($faqtoid) eq "") {
	    &msg($who, "factoid \002$faqtoid\002 does not exist");
	    return;
	}

	if ($function eq "lock") {
	    # strongly requested by #debian on 19991028. -xk
	    if (1 and $faqtoid !~ /^\Q$who\E$/i and &IsFlag("o") ne "o") {
		&msg($who,"sorry, locking cannot be used since it can be abused unneccesarily.");
		&status("Replace 1 with 0 in Process.pl#~324 for locking support.");
		return;
	    }

	    &CmdLock($faqtoid);
	} else {
	    &CmdUnLock($faqtoid);
	}

	return;
    }

    # factoid rename.
    if ($message =~ s/^rename(\s+|$)//) {
	return 'rename: no addr' unless ($addressed);

	if ($message eq "") {
	    &help("rename");
	    return;
	}

	if ($message =~ /^'(.*)'\s+'(.*)'$/) {
	    my($from,$to) = (lc $1, lc $2);

	    my $result = &getFactoid($from);
	    if (defined $result) {
		my $author = &getFactInfo($from, "created_by");

		if (&IsFlag("m") or $author =~ /^\Q$who\E\!/i) {
		    &msg($who, "It's not yours to modify.");
		    return;
		}

		if ($_ = &getFactoid($to)) {
		    &performReply("destination factoid already exists.");
		    return;
		}

		&setFactInfo($from,"factoid_key",$to);

		&status("rename: <$who> '$from' is now '$to'");
		&performReply("i renamed '$from' to '$to'");
	    } else {
		&performReply("i didn't have anything called '$from'");
	    }
	} else {
	    &msg($who,"error: wrong format. ask me about 'help rename'.");
	}

	return;
    }

    # factoid substitution. (X =~ s/A/B/FLAG)
    if ($message =~ m|^(.*?)\s+=~\s+s([/,#])(.+?)\2(.*?)\2([a-z]*);?\s*$|) {
	my ($faqtoid,$delim,$op,$np,$flags) = (lc $1, $2, $3, $4, $5);
	return 'subst: no addr' unless ($addressed);

	# incorrect format.
	if ($np =~ /$delim/) {
	    &msg($who,"looks like you used the delimiter too many times. You may want to use a different delimiter, like ':' or '#'.");
	    return;
	}

	# success.
	if (my $result = &getFactoid($faqtoid)) {
	    return 'subst: locked' if (&IsLocked($faqtoid) == 1);
	    my $was = $result;

	    if (($flags eq "g" && $result =~ s/\Q$op/$np/gi) || $result =~ s/\Q$op/$np/i) {
		if (length $result > $param{'maxDataSize'}) {
		    &performReply("that's too long");
		    return;
		}
		&setFactInfo($faqtoid, "factoid_value", $result);
		&status("update: '$faqtoid' =is=> '$result'; was '$was'");
		&performReply("OK");
	    } else {
		&performReply("that doesn't contain '$op'");
	    }
	} else {
	    &performReply("i didn't have anything called '$faqtoid'");
	}

	return;
    }

    # Fix up $message for question.
    my $question = $message;
    for ($question) {
	# fix the string.
	s/^hey([, ]+)where/where/i;
	s/\s+\?$/?/;
	s/whois/who is/ig;
	s/where can i find/where is/i;
	s/how about/where is/i;
	s/ da / the /ig;

	# clear the string of useless words.
	s/^(stupid )?q(uestion)?:\s+//i;
	s/^(does )?(any|ne)(1|one|body) know //i;

	s/^[uh]+m*[,\.]* +//i;

	s/^well([, ]+)//i;
	s/^still([, ]+)//i;
	s/^(gee|boy|golly|gosh)([, ]+)//i;
	s/^(well|and|but|or|yes)([, ]+)//i;

	s/^o+[hk]+(a+y+)?([,. ]+)//i;
	s/^g(eez|osh|olly)([,. ]+)//i;
	s/^w(ow|hee|o+ho+)([,. ]+)//i;
	s/^heya?,?( folks)?([,. ]+)//i;
    }

    if ($addressed and $message =~ s/^no([, ]+)(\Q$ident\E\,+)?\s*//i) {
	$correction_plausible = 1;
	&status("correction is plausible, initial negative and nick deleted ($&)") if ($param{VERBOSITY});
    } else {
	$correction_plausible = 0;
    }

    my $result = &doQuestion($question);
    if (!defined $result or $result eq $noreply) {
	return 'result from doQ undef.';
    }

    if (defined $result and $result !~ /^0?$/) {	# question.
	&status("question: <$who> $message");
	$count{'Question'}++;
    } elsif (&IsChanConf("perlMath") > 0 and $addressed) { # perl math.
	&loadMyModule("perlMath");
	my $newresult = &perlMath();

	if (defined $newresult and $newresult ne "") {
	    $cmdstats{'Maths'}++;
	    $result = $newresult;
	    &status("math: <$who> $message => $result");
	}
    }

    if ($result !~ /^0?$/) {
	&performStrictReply($result);
	return;
    }

    # why would a friendly bot get passed here?
    if (&IsParam("friendlyBots")) {
	return if (grep lc($_) eq lc($who), split(/\s+/, $param{'friendlyBots'}));
    }

    # do the statement.
    if (!defined &doStatement($message)) {
	return;
    }

    return unless ($addressed);

    if (length $message > 64) {
	&status("unparseable-moron: $message");
#	&performReply( &getRandom(keys %{ $lang{'moron'} }) );
	$count{'Moron'}++;

	&performReply("You are moron #".$count{'Moron'}."!");
	return;
    }

    &status("unparseable: $message");
    &performReply( &getRandom(keys %{ $lang{'dunno'} }) );
    $count{'Dunno'}++;
}

1;
