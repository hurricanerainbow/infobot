#
#  UserDCC.pl: User Commands, DCC CHAT.
#      Author: dms
#     Version: v0.1 (20000707)
#     Created: 20000707 (from UserExtra.pl)
#

if (&IsParam("useStrict")) { use strict; }

sub userDCC {
    # hrm...
    $message =~ s/\s+$//;

    ### for all users.
    # quit.
    if ($message =~ /^(exit|quit)$/i) {
	# do ircII clients support remote close? if so, cool!
	&status("userDCC: quit called. FIXME");
###	$irc->removeconn($dcc{'CHAT'}{lc $who});

	return $noreply;
    }

    # who.
    if ($message =~ /^who$/i) {
	my $count = scalar(keys %{$dcc{'CHAT'}});
	&performStrictReply("Start of who ($count users).");
	foreach (keys %{$dcc{'CHAT'}}) {
	    &performStrictReply("=> $_");
	}
	&performStrictReply("End of who.");

	return $noreply;
    }

    ### for those users with enough flags.

    # 4op.
    if ($message =~ /^4op(\s+($mask{chan}))?$/i) {
	return $noreply unless (&hasFlag("o"));

	my $chan = $2;

	if ($chan eq "") {
	    &help("4op");
	    return $noreply;
	}

	if (!$channels{$chan}{'o'}{$ident}) {
	    &msg($who, "i don't have ops on $chan to do that.");
	    return $noreply;
	}

	# on non-4mode(<4) servers, this may be exploited.
	if ($channels{$chan}{'o'}{$who}) {
	    rawout("MODE $chan -o+o-o+o". (" $who" x 4));
	} else {
	    rawout("MODE $chan +o-o+o-o". (" $who" x 4));
	}

	return $noreply;
    }

    # backlog.
    if ($message =~ /^backlog(\s+(.*))?$/i) {
	return $noreply unless (&hasFlag("o"));
	return $noreply unless (&hasParam("backlog"));
	my $num = $2;
	my $max = $param{'backlog'};

	if (!defined $num) {
	    &help("backlog");
	    return $noreply;
	} elsif ($num !~ /^\d+/) {
	    &msg($who, "error: argument is not positive integer.");
	    return $noreply;
	} elsif ($num > $max or $num < 0) {
	    &msg($who, "error: argument is out of range (max $max).");
	    return $noreply;
	}

	&msg($who, "Start of backlog...");
	for (0..$num-1) {
	    sleep 1 if ($_ % 4 == 0 and $_ != 0);
	    $conn->privmsg($who, "[".($_+1)."]: $backlog[$max-$num+$_]");
	}
	&msg($who, "End of backlog.");

	return $noreply;
    }

    # dump variables.
    if ($message =~ /^dumpvars$/i) {
	return $noreply unless (&hasFlag("o"));
	return '' unless (&IsParam("dumpvars"));

	&status("Dumping all variables...");
	&dumpallvars();

	return $noreply;
    }

    # kick.
    if ($message =~ /^kick(\s+(\S+)(\s+(\S+))?)?/) {
	return $noreply unless (&hasFlag("o"));
	my ($nick,$chan) = (lc $2,lc $4);

	if ($nick eq "") {
	    &help("kick");
	    return $noreply;
	}

	if (&validChan($chan) == 0) {
	    &msg($who,"error: invalid channel \002$chan\002");
	    return $noreply;
	}

	if (&IsNickInChan($nick,$chan) == 0) {
	    &msg($who,"$nick is not in $chan.");
	    return $noreply;
	}

	&kick($nick,$chan);

	return $noreply;
    }

    # part.
    if ($message =~ /^part(\s+(\S+))?$/i) {
	return $noreply unless (&hasFlag("o"));
	my $jchan = $2;

	if ($jchan !~ /^$mask{chan}$/) {
	    &msg($who, "error, invalid chan.");
	    &help("part");
	    return $noreply;
	}

	if (!&validChan($jchan)) {
	    &msg($who, "error, I'm not on that chan.");
	    return $noreply;
	}

	&msg($jchan, "Leaving. (courtesy of $who).");
	&part($jchan);
	return $noreply;
    }

    # ignore.
    if ($message =~ /^ignore(\s+(\S+))?$/i) {
	return $noreply unless (&hasFlag("o"));
	my $what = lc $2;

	if ($what eq "") {
	    &help("ignore");
	    return $noreply;
	}

	my $expire = $param{'ignoreTempExpire'} || 60;
	$ignoreList{$what} = time() + ($expire * 60);
	&status("ignoring $what at $who's request");
	&msg($who, "added $what to the ignore list");

	return $noreply;
    }

    # unignore.
    if ($message =~ /^unignore(\s+(\S+))?$/i) {
	return $noreply unless (&hasFlag("o"));
	my $what = $2;

	if ($what eq "") {
	    &help("unignore");
	    return $noreply;
	}

	if ($ignoreList{$what}) {
	    &status("unignoring $what at $userHandle's request");
	    delete $ignoreList{$what};
	    &msg($who, "removed $what from the ignore list");
	} else {
	    &status("unignore FAILED for $1 at $who's request");
	    &msg($who, "no entry for $1 on the ignore list");
	}
	return $noreply;
    }

    # clear unignore list.
    if ($message =~ /^clear ignorelist$/i) {
	return $noreply unless (&hasFlag("o"));
	undef %ignoreList;
	&status("unignoring all ($who said the word)");

	return $noreply;
    }

    # lobotomy. sometimes we want the bot to be _QUIET_.
    if ($message =~ /^(lobotomy|bequiet)$/i) {
	return $noreply unless (&hasFlag("o"));

	if ($lobotomized) {
	    &performReply("i'm already lobotomized");
	} else {
	    &performReply("i have been lobotomized");
	    $lobotomized = 1;
	}

	return $noreply;
    }

    # unlobotomy.
    if ($message =~ /^(unlobotomy|benoisy)$/i) {
	return $noreply unless (&hasFlag("o"));
	if ($lobotomized) {
	    &performReply("i have been unlobotomized, woohoo");
	    $lobotomized = 0;
	} else {
	    &performReply("i'm not lobotomized");
	}
	return $noreply;
    }

    # op.
    if ($message =~ /^op(\s+(.*))?$/i) {
	return $noreply unless (&hasFlag("o"));
	my ($opee) = lc $2;
	my @chans;

	if ($opee =~ / /) {
	    if ($opee =~ /^(\S+)\s+(\S+)$/) {
		$opee  = $1;
		@chans = ($2);
		if (!&validChan($2)) {
		    &msg($who,"error: invalid chan ($2).");
		    return $noreply;
		}
	    } else {
		&msg($who,"error: invalid params.");
		return $noreply;
	    }
	} else {
	    @chans = keys %channels;
	}

	my $found = 0;
	my $op = 0;
	foreach (@chans) {
	    next unless (&IsNickInChan($opee,$_));
	    $found++;
	    if ($channels{$_}{'o'}{$opee}) {
		&status("op: $opee already has ops on $_");
		next;
	    }
	    $op++;

	    &status("opping $opee on $_ at ${who}'s request");
	    &performStrictReply("opping $opee on $_");
	    &op($_, $opee);
	}

	if ($found != $op) {
	    &status("op: opped on all possible channels.");
	} else {
	    &DEBUG("found => '$found'.");
	    &DEBUG("op => '$op'.");
	}

	return $noreply;
    }

    # deop.
    if ($message =~ /^deop(\s+(.*))?$/i) {
	return $noreply unless (&hasFlag("o"));
	my ($opee) = lc $2;
	my @chans;

	if ($opee =~ / /) {
	    if ($opee =~ /^(\S+)\s+(\S+)$/) {
		$opee  = $1;
		@chans = ($2);
		if (!&validChan($2)) {
		    &msg($who,"error: invalid chan ($2).");
		    return $noreply;
		}
	    } else {
		&msg($who,"error: invalid params.");
		return $noreply;
	    }
	} else {
	    @chans = keys %channels;
	}

	my $found = 0;
	my $op = 0;
	foreach (@chans) {
	    next unless (&IsNickInChan($opee,$_));
	    $found++;
	    if (!exists $channels{$_}{'o'}{$opee}) {
		&status("deop: $opee already has no ops on $_");
		next;
	    }
	    $op++;

	    &status("deopping $opee on $_ at ${who}'s request");
	    &deop($_, $opee);
	}

	if ($found != $op) {
	    &status("deop: deopped on all possible channels.");
	} else {
	    &DEBUG("deop: found => '$found'.");
	    &DEBUG("deop: op => '$op'.");
	}

	return $noreply;
    }

    # say.
    if ($message =~ s/^say\s+(\S+)\s+(.*)//) {
	return $noreply unless (&hasFlag("o"));
	my ($chan,$msg) = (lc $1, $2);
	&DEBUG("chan => '$1', msg => '$msg'.");

	if (&validChan($chan)) {
	    &msg($chan, $2);
	} else {
	    &msg($who,"i'm not on \002$1\002, sorry.");
	}
	return $noreply;
    }

    # die.
    if ($message =~ /^die$/) {
	return $noreply unless (&hasFlag("n"));

	&doExit();

	status("Dying by $who\'s request");
	exit 0;
    }

    # global factoid substitution.
    if ($message =~ m|^s([/,#])(.+?)\1(.*?)\1;?\s*$|) {
	my ($delim,$op,$np) = ($1, $2, $3);
	return $noreply unless (&hasFlag("n"));
	### TODO: support flags to do full-on global.

	# incorrect format.
	if ($np =~ /$delim/) {
	    &performReply("looks like you used the delimiter too many times. You may want to use a different delimiter, like ':' or '#'.");
	    return $noreply;
	}

	### TODO: fix up $op to support mysql/pgsql/dbm(perl)
	### TODO: => add db/sql specific function to fix this.
	my @list = &searchTable("factoids", "factoid_key",
			"factoid_value", $op);

	if (!scalar @list) {
	    &performReply("Expression didn't match anything.");
	    return $noreply;
	}

	if (scalar @list > 100) {
	    &performReply("regex found more than 100 matches... not doing.");
	    return $noreply;
	}

	&status("gsubst: going to alter ".scalar(@list)." factoids.");
	&performReply("going to alter ".scalar(@list)." factoids.");

	my $error = 0;
	foreach (@list) {
	    my $faqtoid = $_;

	    next if (&IsLocked($faqtoid) == 1);
	    my $result = &getFactoid($faqtoid);
	    my $was = $result;
	    &DEBUG("was($faqtoid) => '$was'.");

	    # global global
	    # we could support global local (once off).
	    if ($result =~ s/\Q$op/$np/gi) {
		if (length $result > $param{'maxDataSize'}) {
		    &performReply("that's too long (or was long)");
		    return $noreply;
		}
		&setFactInfo($faqtoid, "factoid_value", $result);
		&status("update: '$faqtoid' =is=> '$result'; was '$was'");
	    } else {
		&WARN("subst: that's weird... thought we found the string ($op) in '$faqtoid'.");
		$error++;
	    }
	}

	if ($error) {
	    &ERROR("Some warnings/errors?");
	}

	&performReply("Ok... did s/$op/$np/ for ".
				(scalar(@list) - $error)." factoids");

	return $noreply;
    }

    # jump.
    if ($message =~ /^jump(\s+(\S+))?$/i) {
	return $noreply unless (&hasFlag("n"));

	if ($2 eq "") {
	    &help("jump");
	    return $noreply;
	}

	my ($server,$port);
	if ($2 =~ /^(\S+)(:(\d+))?$/) {
	    $server = $1;
	    $port   = $3 || 6667;
	} else {
	    &msg($who,"invalid format.");
	    return $noreply;
	}

	&status("jumping servers... $server...");
	&rawout("QUIT :jumping to $server");

	if (&irc($server,$port) == 0) {
	    &ircloop();
	}
    }

    # reload.
    if ($message =~ /^reload$/i) {
	return $noreply unless (&hasFlag("n"));

	&status("USER reload $who");
	&msg($who,"reloading...");
	&reloadAllModules();
	&msg($who,"reloaded.");

	return $noreply;
    }

    # rehash.
    if ($message =~ /^rehash$/) {
	return $noreply unless (&hasFlag("n"));

	&msg($who,"rehashing...");
	&restart("REHASH");
	&status("USER rehash $who");
	&msg($who,"rehashed");

	return $noreply;
    }

    # set.
    if ($message =~ /^set(\s+(\S+)?(\s+(.*))?)?$/i) {
	return $noreply unless (&hasFlag("n"));
	my ($param,$what) = ($2,$4);

	if ($param eq "" and $what eq "") {
	    &msg($who,"\002Usage\002: set <param> [what]");
	    return $noreply;
	}

	if (!exists $param{$param}) {
	    &msg($who,"error: param{$param} cannot be set");
	    return $noreply;
	}

	if ($what eq "") {
	    if ($param{$param} eq "") {
		&msg($who,"param{$param} has \002no value\002.");
	    } else {
		&msg($who,"param{$param} has value of '\002$param{$param}\002'.");
	    }
	    return $noreply;
	}

	if ($param{$param} eq $what) {
	    &msg($who,"param{$param} already has value of '\002$what\002'.");
	    return $noreply;
	}

	$param{$param} = $what;
	&msg($who,"setting param{$param} to '\002$what\002'.");

	return $noreply;
    }

    # unset.
    if ($message =~ /^unset(\s+(\S+))?$/i) {
	return $noreply unless (&hasFlag("n"));
	my ($param) = $2;

	if ($param eq "") {
	    &msg($who,"\002Usage\002: unset <param>");
	    return $noreply;
	}

	if (!exists $param{$param}) {
	    &msg($who,"error: \002$param\002 cannot be unset");
	    return $noreply;
	}

	if ($param{$param} == 0) {
	    &msg($who,"\002param{$param}\002 has already been unset.");
	    return $noreply;
	}

	$param{$param} = 0;
	&msg($who,"unsetting \002param{$param}\002.");

	return $noreply;
    }

    # more...
}

1;
