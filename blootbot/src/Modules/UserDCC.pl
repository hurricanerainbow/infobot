#
#  UserDCC.pl: User Commands, DCC CHAT.
#      Author: dms
#     Version: v0.2 (20010119)
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
	&dcc_close($who);
	&status("userDCC: after dcc_close!");

	return;
    }

    # who.
    if ($message =~ /^who$/) {
	my $count = scalar(keys %{$dcc{'CHAT'}});
	my $dccCHAT = $message;

	&pSReply("Start of who ($count users).");
	foreach (keys %{$dcc{'CHAT'}}) {
	    &pSReply("=> $_");
	}
	&pSReply("End of who.");

	return;
    }

    ### for those users with enough flags.

    # 4op.
    if ($message =~ /^4op(\s+($mask{chan}))?$/i) {
	return unless (&hasFlag("o"));

	my $chan = $2;

	if ($chan eq "") {
	    &help("4op");
	    return;
	}

	if (!$channels{$chan}{'o'}{$ident}) {
	    &msg($who, "i don't have ops on $chan to do that.");
	    return;
	}

	# on non-4mode(<4) servers, this may be exploited.
	if ($channels{$chan}{'o'}{$who}) {
	    rawout("MODE $chan -o+o-o+o". (" $who" x 4));
	} else {
	    rawout("MODE $chan +o-o+o-o". (" $who" x 4));
	}

	return;
    }

    # backlog.
    if ($message =~ /^backlog(\s+(.*))?$/i) {
	return unless (&hasFlag("o"));
	return unless (&hasParam("backlog"));
	my $num = $2;
	my $max = $param{'backlog'};

	if (!defined $num) {
	    &help("backlog");
	    return;
	} elsif ($num !~ /^\d+/) {
	    &msg($who, "error: argument is not positive integer.");
	    return;
	} elsif ($num > $max or $num < 0) {
	    &msg($who, "error: argument is out of range (max $max).");
	    return;
	}

	&msg($who, "Start of backlog...");
	for (0..$num-1) {
	    sleep 1 if ($_ % 4 == 0 and $_ != 0);
	    $conn->privmsg($who, "[".($_+1)."]: $backlog[$max-$num+$_]");
	}
	&msg($who, "End of backlog.");

	return;
    }

    # dump variables.
    if ($message =~ /^dumpvars$/i) {
	return unless (&hasFlag("o"));
	return unless (&IsParam("dumpvars"));

	&status("Dumping all variables...");
	&dumpallvars();

	return;
    }

    # kick.
    if ($message =~ /^kick(\s+(\S+)(\s+(\S+))?)?/) {
	return unless (&hasFlag("o"));
	my ($nick,$chan) = (lc $2,lc $4);

	if ($nick eq "") {
	    &help("kick");
	    return;
	}

	if (&validChan($chan) == 0) {
	    &msg($who,"error: invalid channel \002$chan\002");
	    return;
	}

	if (&IsNickInChan($nick,$chan) == 0) {
	    &msg($who,"$nick is not in $chan.");
	    return;
	}

	&kick($nick,$chan);

	return;
    }

    # kick.
    if ($message =~ /^mode(\s+(.*))?$/) {
	return unless (&hasFlag("n"));
	my ($chan,$mode) = split /\s+/,$2,2;

	if ($chan eq "") {
	    &help("mode");
	    return;
	}

	if (&validChan($chan) == 0) {
	    &msg($who,"error: invalid channel \002$chan\002");
	    return;
	}

	if (!$channels{$chan}{o}{$ident}) {
	    &msg($who,"error: don't have ops on \002$chan\002");
	    return;
	}

	&mode($chan, $mode);

	return;
    }

    # part.
    if ($message =~ /^part(\s+(\S+))?$/i) {
	return unless (&hasFlag("o"));
	my $jchan = $2;

	if ($jchan !~ /^$mask{chan}$/) {
	    &msg($who, "error, invalid chan.");
	    &help("part");
	    return;
	}

	if (!&validChan($jchan)) {
	    &msg($who, "error, I'm not on that chan.");
	    return;
	}

	&msg($jchan, "Leaving. (courtesy of $who).");
	&part($jchan);
	return;
    }

    # lobotomy. sometimes we want the bot to be _QUIET_.
    if ($message =~ /^(lobotomy|bequiet)$/i) {
	return unless (&hasFlag("o"));

	if ($lobotomized) {
	    &performReply("i'm already lobotomized");
	} else {
	    &performReply("i have been lobotomized");
	    $lobotomized = 1;
	}

	return;
    }

    # unlobotomy.
    if ($message =~ /^(unlobotomy|benoisy)$/i) {
	return unless (&hasFlag("o"));

	if ($lobotomized) {
	    &performReply("i have been unlobotomized, woohoo");
	    $lobotomized = 0;
	    delete $cache{lobotomy};
#	    undef $cache{lobotomy};	# ??
	} else {
	    &performReply("i'm not lobotomized");
	}

	return;
    }

    # op.
    if ($message =~ /^op(\s+(.*))?$/i) {
	return unless (&hasFlag("o"));
	my ($opee) = lc $2;
	my @chans;

	if ($opee =~ / /) {
	    if ($opee =~ /^(\S+)\s+(\S+)$/) {
		$opee  = $1;
		@chans = ($2);
		if (!&validChan($2)) {
		    &msg($who,"error: invalid chan ($2).");
		    return;
		}
	    } else {
		&msg($who,"error: invalid params.");
		return;
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
		&pSReply("op: $opee already has ops on $_");
		next;
	    }
	    $op++;

	    &pSReply("opping $opee on $_");
	    &op($_, $opee);
	}

	if ($found != $op) {
	    &pSReply("op: opped on all possible channels.");
	} else {
	    &DEBUG("op: found => '$found'.");
	    &DEBUG("op:    op => '$op'.");
	}

	return;
    }

    # deop.
    if ($message =~ /^deop(\s+(.*))?$/i) {
	return unless (&hasFlag("o"));
	my ($opee) = lc $2;
	my @chans;

	if ($opee =~ / /) {
	    if ($opee =~ /^(\S+)\s+(\S+)$/) {
		$opee  = $1;
		@chans = ($2);
		if (!&validChan($2)) {
		    &msg($who,"error: invalid chan ($2).");
		    return;
		}
	    } else {
		&msg($who,"error: invalid params.");
		return;
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

	return;
    }

    # say.
    if ($message =~ s/^say\s+(\S+)\s+(.*)//) {
	return unless (&hasFlag("o"));
	my ($chan,$msg) = (lc $1, $2);
	&DEBUG("chan => '$1', msg => '$msg'.");

	if (&validChan($chan)) {
	    &msg($chan, $2);
	} else {
	    &msg($who,"i'm not on \002$1\002, sorry.");
	}
	return;
    }

    # die.
    if ($message =~ /^die$/) {
	return unless (&hasFlag("n"));

	&doExit();

	&status("Dying by $who\'s request");
	exit 0;
    }

    # global factoid substitution.
    if ($message =~ m|^s([/,#])(.+?)\1(.*?)\1;?\s*$|) {
	my ($delim,$op,$np) = ($1, $2, $3);
	return unless (&hasFlag("n"));
	### TODO: support flags to do full-on global.

	# incorrect format.
	if ($np =~ /$delim/) {
	    &performReply("looks like you used the delimiter too many times. You may want to use a different delimiter, like ':' or '#'.");
	    return;
	}

	### TODO: fix up $op to support mysql/pgsql/dbm(perl)
	### TODO: => add db/sql specific function to fix this.
	my @list = &searchTable("factoids", "factoid_key",
			"factoid_value", $op);

	if (!scalar @list) {
	    &performReply("Expression didn't match anything.");
	    return;
	}

	if (scalar @list > 100) {
	    &performReply("regex found more than 100 matches... not doing.");
	    return;
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
		    return;
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

	return;
    }

    # jump.
    if ($message =~ /^jump(\s+(\S+))?$/i) {
	return unless (&hasFlag("n"));

	if ($2 eq "") {
	    &help("jump");
	    return;
	}

	my ($server,$port);
	if ($2 =~ /^(\S+)(:(\d+))?$/) {
	    $server = $1;
	    $port   = $3 || 6667;
	} else {
	    &msg($who,"invalid format.");
	    return;
	}

	&status("jumping servers... $server...");
	&rawout("QUIT :jumping to $server");

	if (&irc($server,$port) == 0) {
	    &ircloop();
	}
    }

    # reload.
    if ($message =~ /^reload$/i) {
	return unless (&hasFlag("n"));

	&status("USER reload $who");
	&pSReply("reloading...");
	&reloadAllModules();
	&pSReply("reloaded.");

	return;
    }

    # rehash.
    if ($message =~ /^rehash$/) {
	return unless (&hasFlag("n"));

	&msg($who,"rehashing...");
	&restart("REHASH");
	&status("USER rehash $who");
	&msg($who,"rehashed");

	return;
    }

    #####
    ##### USER//CHAN SPECIFIC CONFIGURATION COMMANDS
    #####

    if ($message =~ /^chaninfo(\s+(.*))?$/) {
	my @args = split /[\s\t]+/, $2;	# hrm.

	if (scalar @args != 1) {
	    &help("chaninfo");
	    return;
	}

	if (!exists $chanconf{$args[0]}) {
	    &pSReply("no such channel $args[0]");
	    return;
	}

	&pSReply("showing channel conf.");
	foreach (sort keys %{ $chanconf{$args[0]} }) {
	    &pSReply("$chan: $_ => $chanconf{$args[0]}{$_}");
	}
	&pSReply("End of chaninfo.");

	return;
    }

    # +chan.
    if ($message =~ /^(chanset|\+chan)(\s+(.*?))?$/) {
	my $cmd		= $1;
	my $args	= $3;
	my $no_chan	= 0;

	if (!defined $args) {
	    &help($cmd);
	    return;
	}

	my @chans;
	while ($args =~ s/^($mask{chan})\s*//) {
	    push(@chans, $1);
	}

	if (!scalar @chans) {
	    push(@chans, "_default");
	    $no_chan	= 1;
	}

	my($what,$val) = split /[\s\t]+/, $args, 2;

	### TODO: "cannot set values without +m".
	return unless (&hasFlag("n"));

	# READ ONLY.
	if (defined $what and $what !~ /^[-+]/ and !defined $val and $no_chan) {
	    &pSReply("Showing $what values on all channels...");

	    my %vals;
	    foreach (keys %chanconf) {
		my $val = $chanconf{$_}{$what} || "NOT-SET";
		$vals{$val}{$_} = 1;
	    }

	    foreach (keys %vals) {
		&pSReply("  $what = $_: ".join(' ', keys %{ $vals{$_} } ) );
	    }

	    &pSReply("End of list.");

	    return;
	}

	### TODO: move to UserDCC again.
	if ($cmd eq "chanset" and !defined $what) {
	    &DEBUG("showing channel conf.");

	    foreach $chan ($chan, "_default") {
		&pSReply("chan: $chan");
		### TODO: merge 2 or 3 per line.
		my @items;
		my $str = "";
		foreach (sort keys %{ $chanconf{$chan} }) {
		    my $newstr = join(', ', @items);
		    if (length $newstr > 60) {
			&pSReply("    $str");
			@items = ();
		    }
		    $str = $newstr;
		    push(@items, "$_ => $chanconf{$chan}{$_}");
		}
		&pSReply("    $str") if (@items);
	    }
	    return;
	}

	foreach (@chans) {
	    &chanSet($cmd, $_, $what, $val);
	}

	return;
    }

    if ($message =~ /^(chanunset|\-chan)(\s+(.*))?$/) {
	return unless (&hasFlag("n"));
	my $args	= $3;
	my $no_chan	= 0;

	if (!defined $args) {
	    &help("chanunset");
	    return;
	}

	my ($chan);
	my $delete	= 0;
	if ($args =~ s/^(\-)?($mask{chan})\s*//) {
	    $chan	= $2;
	    $delete	= ($1) ? 1 : 0;
	    &DEBUG("chan => $chan.");
	} else {
	    &VERB("no chan arg; setting to default.",2);
	    $chan	= "_default";
	    $no_chan	= 1;
	}

	if (!exists $chanconf{$chan}) {
	    &pSReply("no such channel $chan");
	    return;
	}

	if ($args ne "") {

	    if (!&getChanConf($args,$chan)) {
		&pSReply("$args does not exist for $chan");
		return;
	    }

	    my @chans = &ChanConfList($args);
	    &DEBUG("scalar chans => ".scalar(@chans) );
	    if (scalar @chans == 1 and $chans[0] eq "_default" and !$no_chan) {
		&psReply("ok, $args was set only for _default; unsetting for _defaul but setting for other chans.");

		my $val = $chanconf{$_}{_default};
		foreach (keys %chanconf) {
		    $chanconf{$_}{$args} = $val;
		}
		delete $chanconf{_default}{$args};

		return;
	    }

	    if ($no_chan and !exists($chanconf{_default}{$args})) {
		&pSReply("ok, $args for _default does not exist, removing from all chans.");

		foreach (keys %chanconf) {
		    next unless (exists $chanconf{$_}{$args});
		    &DEBUG("delete chanconf{$_}{$args};");
		    delete $chanconf{$_}{$args};
		}

		return;
	    }

	    &pSReply("Unsetting channel ($chan) option $args. (was $chanconf{$chan}{$args})");
	    delete $chanconf{$chan}{$args};

	    return;
	}

	if ($delete) {
	    &pSReply("Deleting channel $chan for sure!");
	    $utime_chanfile = time();
	    $ucount_chanfile++;

	    &part($chan);
	    &pSReply("Leaving $chan...");

	    delete $chanconf{$chan};
	} else {
	    &pSReply("Prefix channel with '-' to delete for sure.");
	}

	return;
    }

    if ($message =~ /^newpass(\s+(.*))?$/) {
	my(@args) = split /[\s\t]+/, $2 || '';

	if (scalar @args != 1) {
	    &help("newpass");
	    return;
	}

	my $u		= &getUser($who);
	my $crypt	= &mkcrypt($args[0]);

	&pSReply("Set your passwd to '$crypt'");
	$users{$u}{PASS} = $crypt;

	$utime_userfile = time();
	$ucount_userfile++;

	return;
    }

    if ($message =~ /^chpass(\s+(.*))?$/) {
	my(@args) = split /[\s\t]+/, $2 || '';

	if (!scalar @args) {
	    &help("chpass");
	    return;
	}

	if (!&IsUser($args[0])) {
	    &pSReply("user $args[0] is not valid.");
	    return;
	}

	my $u = &getUser($args[0]);
	if (!defined $u) {
	    &pSReply("Internal error, u = NULL.");
	    return;
	}

	if (scalar @args == 1) {	# del pass.
	    if (!&IsFlag("n") and $who !~ /^\Q$verifyUser\E$/i) {
		&pSReply("cannto remove passwd of others.");
		return;
	    }

	    if (!exists $users{$u}{PASS}) {
		&pSReply("$u does not have pass set anyway.");
		return;
	    }

	    &pSReply("Deleted pass from $u.");

	    $utime_userfile = time();
	    $ucount_userfile++;

	    delete $users{$u}{PASS};

	    return;
	}

	my $crypt	= &mkcrypt($args[1]);
	&pSReply("Set $u's passwd to '$crypt'");
	$users{$u}{PASS} = $crypt;

	$utime_userfile = time();
	$ucount_userfile++;

	return;
    }

    if ($message =~ /^chattr(\s+(.*))?$/) {
	my(@args) = split /[\s\t]+/, $2 || '';

	if (!scalar @args) {
	    &help("chattr");
	    return;
	}

	my $user;
	if ($args[0] =~ /^$mask{nick}$/i) {	# <nick>
	    $user	= &getUser($args[0]);
	    $chflag	= $args[1];
	} else {				# <flags>
	    $user	= &getUser($who);
	    &DEBUG("user $who... nope.") unless (defined $user);
	    $user	= &getUser($verifyUser);
	    $chflag	= $args[0];
	}

	if (!defined $user) {
	    &pSReply("user does not exist.");
	    return;
	}

	my $flags = $users{$user}{FLAGS};
	if (!defined $chflag) {
	    &pSReply("Flags for $user: $flags");
	    return;
	}

	&DEBUG("who => $who");
	&DEBUG("verifyUser => $verifyUser");
	if (!&IsFlag("n") and $who !~ /^\Q$verifyUser\E$/i) {
	    &pSReply("cannto change attributes of others.");
	    return "REPLY";
	}

	my $state;
	my $change	= 0;
	foreach (split //, $chflag) {
	    if ($_ eq "+") { $state = 1; next; }
	    if ($_ eq "-") { $state = 0; next; }

	    if (!defined $state) {
		&pSReply("no initial + or - was found in attr.");
		return;
	    }

	    if ($state) {
		next if ($flags =~ /\Q$_\E/);
		$flags .= $_;
	    } else {
		if (&IsParam("owner")
			and $param{owner} =~ /^\Q$user\E$/i
			and $flags =~ /[nmo]/
		) {
		    &pSReply("not removing flag $_ for $user.");
		    next;
		}
		next unless ($flags =~ s/\Q$_\E//);
	    }

	    $change++;
	}

	if ($change) {
	    $utime_userfile = time();
	    $ucount_userfile++;
	    &pSReply("Current flags: $flags");
	    $users{$user}{FLAGS} = $flags;
	} else {
	    &pSReply("No flags changed: $flags");
	}

	return;
    }

    if ($message =~ /^chnick(\s+(.*))?$/) {
	my(@args) = split /[\s\t]+/, $2 || '';

	if ($who eq "_default") {
	    &WARN("$who or verifyuser tried to run chnick.");
	    return "REPLY";
	}

	if (!scalar @args or scalar @args > 2) {
	    &help("chnick");
	    return;
	}

	if (scalar @args == 1) {	# 1
	    $user	= &getUser($who);
	    &DEBUG("nope, not $who.") unless (defined $user);
	    $user	||= &getUser($verifyUser);
	    $chnick	= $args[0];
	} else {			# 2
	    $user	= &getUser($args[0]);
	    $chnick	= $args[1];
	}

	if (!defined $user) {
	    &pSReply("user $who or $args[0] does not exist.");
	    return;
	}

	if ($user =~ /^\Q$chnick\E$/i) {
	    &pSReply("user == chnick. why should I do that?");
	    return;
	}

	if (&getUser($chnick)) {
	    &pSReply("user $chnick is already used!");
	    return;
	}

	if (!&IsFlag("n") and $who !~ /^\Q$verifyUser\E$/i) {
	    &pSReply("cannto change nick of others.");
	    return "REPLY" if ($who eq "_default");
	    return;
	}

	foreach (keys %{ $users{$user} }) {
	    $users{$chnick}{$_} = $users{$user}{$_};
	    delete $users{$user}{$_};
	}
	undef $users{$user};	# ???

	$utime_userfile = time();
	$ucount_userfile++;

	&pSReply("Changed '$user' to '$chnick' successfully.");

	return;
    }

    if ($message =~ /^([-+])host(\s+(.*))?$/) {
	my $cmd		= $1."host";
	my(@args)	= split /[\s\t]+/, $3 || '';
	my $state	= ($1 eq "+") ? 1 : 0;

	if (!scalar @args) {
	    &help($cmd);
	    return;
	}

	if ($who eq "_default") {
	    &WARN("$who or verifyuser tried to run $cmd.");
	    return "REPLY";
	}

	my ($user,$mask);
	if ($args[0] =~ /^$mask{nick}$/i) {	# <nick>
	    return unless (&hasFlag("n"));
	    $user	= &getUser($args[0]);
	    $mask	= $args[1];
	} else {				# <mask>
	    # who or verifyUser. FIXME!!!
	    $user	= &getUser($who);
	    $mask	= $args[0];
	}

	if (!defined $user) {
	    &pSReply("user $user does not exist.");
	    return;
	}

	if (!defined $mask) {
	    ### FIXME.
	    &pSReply("Hostmasks for $user: $users{$user}{HOSTS}");

	    return;
	}

	if (!&IsFlag("n") and $who !~ /^\Q$verifyUser\E$/i) {
	    &pSReply("cannto change masks of others.");
	    return;
	}

	if ($mask !~ /^$mask{nuh}$/) {
	    &pSReply("error: mask ($mask) is not a real hostmask.");
	    return;
	}

	my $count = scalar keys %{ $users{$user}{HOSTS} };

	if ($state) {				# add.
	    if (exists $users{$user}{HOSTS}{$mask}) {
		&pSReply("mask $mask already exists.");
		return;
	    }

	    ### TODO: override support.
	    $users{$user}{HOSTS}{$mask} = 1;

	    &pSReply("Added $mask to list of masks.");

	} else {				# delete.

	    if (!exists $users{$user}{HOSTS}{$mask}) {
		&pSReply("mask $mask does not exist.");
		return;
	    }

	    ### TODO: wildcard support. ?
	    delete $users{$user}{HOSTS}{$mask};

	    if (scalar keys %{ $users{$user}{HOSTS} } != $count) {
		&pSReply("Removed $mask from list of masks.");
	    } else {
		&pSReply("error: could not find $mask in list of masks.");
		return;
	    }
	}

	$utime_userfile	= time();
	$ucount_userfile++;

	return;
    }

    if ($message =~ /^([-+])ban(\s+(.*))?$/) {
	my $cmd		= $1."ban";
	my $flatarg	= $3;
	my(@args)	= split /[\s\t]+/, $3 || '';
	my $state	= ($1 eq "+") ? 1 : 0;

	if (!scalar @args) {
	    &help($cmd);
	    return;
	}

	my($mask,$chan,$time,$reason);

	if ($flatarg =~ s/^($mask{nuh})\s*//) {
	    $mask = $1;
	} else {
	    &DEBUG("arg does not contain nuh mask?");
	}

	if ($flatarg =~ s/^($mask{chan})\s*//) {
	    $chan = $1;
	} else {
	    $chan = "*";	# _default instead?
	}

	if ($state == 0) {		# delete.
	    my @c = &banDel($mask);

	    foreach (@c) {
		&unban($mask, $_);
	    }

	    if ($c) {
		&pSReply("Removed $mask from chans: @c");
	    } else {
		&pSReply("$mask was not found in ban list.");
	    }

	    return;
	}

	###
	# add ban.
	###

	# time.
	if ($flatarg =~ s/^(\d+)\s*//) {
	    $time = $1;
	    &DEBUG("time = $time.");
	    if ($time < 0) {
		&pSReply("error: time cannot be negatime?");
		return;
	    }
	} else {
	    $time = 0;
	}

	if ($flatarg =~ s/^(.*)$//) {	# need length?
	    $reason	= $1;
	}

	if (!&IsFlag("n") and $who !~ /^\Q$verifyUser\E$/i) {
	    &pSReply("cannto change masks of others.");
	    return;
	}

	if ($mask !~ /^$mask{nuh}$/) {
	    &pSReply("error: mask ($mask) is not a real hostmask.");
	    return;
	}

	if ( &banAdd($mask,$chan,$time,$reason) == 2) {
	    &pSReply("ban already exists; overwriting.");
	}
	&pSReply("Added $mask for $chan (time => $time, reason => $reason)");

	return;
    }

    if ($message =~ /^whois(\s+(.*))?$/) {
	my $arg = $2;

	if (!defined $arg) {
	    &help("whois");
	    return;
	}

	my $user = &getUser($arg);
	if (!defined $user) {
	    &pSReply("whois: user $user does not exist.");
	    return;
	}

	### TODO: better (eggdrop-like) output.
	&pSReply("user: $user");
	foreach (keys %{ $users{$user} }) {
	    my $ref = ref $users{$user}{$_};

	    if ($ref eq "HASH") {
		my $type = $_;
		### DOES NOT WORK???
		foreach (keys %{ $users{$user}{$type} }) {
		    &pSReply("    $type => $_");
		}
		next;
	    }

	    &pSReply("    $_ => $users{$user}{$_}");
	}
	&pSReply("End of USER whois.");

	return;
    }

    if ($message =~ /^bans(\s+(.*))?$/) {
	my $arg	= $2;

	if (defined $arg) {
	    if ($arg ne "_default" and !&validChan($arg) ) {
		&pSReply("error: chan $chan is invalid.");
		return;
	    }
	}

	if (!scalar keys %bans) {
	    &pSReply("Ban list is empty.");
	    return;
	}

	my $c;
	&pSReply("     mask: expire, time-added, count, who-by, reason");
	foreach $c (keys %bans) {
	    next unless (!defined $arg or $arg =~ /^\Q$c\E$/i);
	    &pSReply("  $c:");

	    foreach (keys %{ $bans{$c} }) {
		my $val = $bans{$c}{$_};

		if (ref $val eq "ARRAY") {
		    my @array = @{ $val };
		    &pSReply("    $_: @array");
		} else {
		    &DEBUG("unknown ban: $val");
		}
	    }
	}
	&pSReply("END of bans.");

	return;
    }

    if ($message =~ /^banlist(\s+(.*))?$/) {
	my $arg	= $2;

	if (defined $arg and $arg !~ /^$mask_chan$/) {
	    &pSReply("error: chan $chan is invalid.");
	    return;
	}

	&DEBUG("bans for global or arg => $arg.");
	foreach (keys %bans) {			#CHANGE!!!
	    &DEBUG("  $_ => $bans{$_}.");
	}

	&DEBUG("End of bans.");
	&pSReply("END of bans.");

	return;
    }

    if ($message =~ /^save$/) {
	return unless (&hasFlag("o"));

	&writeUserFile();
	&writeChanFile();

	return;
    }

    ### ALIASES.
    $message =~ s/^addignore/+ignore/;
    $message =~ s/^(del|un)ignore/-ignore/;

    # ignore.
    if ($message =~ /^(\+|\-)ignore(\s+(.*))?$/i) {
	return unless (&hasFlag("o"));
	my $state	= ($1 eq "+") ? 1 : 0;
	my $str		= $1."ignore";
	my $args	= $3;

	if (!$args) {
	    &help($str);
	    return;
	}

	my($mask,$chan,$time,$comment);

	# mask.
	if ($args =~ s/^($mask{nuh})\s*//) {
	    $mask = $1;
	} else {
	    &ERROR("no NUH mask?");
	    return;
	}

	if (!$state) {			# delignore.
	    if ( &ignoreDel($mask) ) {
		&pSReply("ok, deleted X ignores.");
	    } else {
		&pSReply("could not find $mask in ignore list.");
	    }
	    return;
	}

	###
	# addignore.
	###

	# chan.
	if ($args =~ s/^($mask{chan}|\*)\s*//) {
	    $chan = $1;
	} else {
	    $chan = "*";
	}

	# time.
	if ($args =~ s/^(\d+)\s*//) {
	    $time = $1*60;	# ??
	} else {
	    $time = 0;
	}

	# time.
	if ($args) {
	    $comment = $args;
	} else {
	    $comment = "added by $who";
	}

	if ( &ignoreAdd($mask, $chan, $time, $comment) > 1) {
	    &pSReply("warn: $mask already in ignore list; written over anyway. FIXME");
	} else {
	    &pSReply("added $mask to ignore list.");
	}

	return;
    }

    if ($message =~ /^ignore(\s+(.*))?$/) {
	my $arg	= $2;

	if (defined $arg) {
	    if ($arg !~ /^$mask{chan}$/) {
		&pSReply("error: chan $chan is invalid.");
		return;
	    }

	    if (!&validChan($arg)) {
		&pSReply("error: chan $arg is invalid.");
		return;
	    }

	    &pSReply("Showing bans for $arg only.");
	}

	if (!scalar keys %ignore) {
	    &pSReply("Ignore list is empty.");
	    return;
	}

	### TODO: proper (eggdrop-like) formatting.
	my $c;
	&pSReply("    mask: expire, time-added, who, comment");
	foreach $c (keys %ignore) {
	    next unless (!defined $arg or $arg =~ /^\Q$c\E$/i);
	    &pSReply("  $c:");

	    foreach (keys %{ $ignore{$c} }) {
		my $ref = ref $ignore{$c}{$_};
		if ($ref eq "ARRAY") {
		    my @array = @{ $ignore{$c}{$_} };
		    &pSReply("      $_: @array");
		} else {
		    &DEBUG("unknown ignore line?");
		}
	    }
	}
	&pSReply("END of ignore.");

	return;
    }

    # adduser/deluser.
    if ($message =~ /^(\+|\-|add|del)user(\s+(.*))?$/i) {
	my $str		= $1;
	my $strstr	= $1."user";
	my @args	= split /\s+/, $3 || '';
	my $args	= $3;
	my $state	= ($str =~ /^(\+|add)$/) ? 1 : 0;

	if (!scalar @args) {
	    &help($strstr);
	    return;
	}

	if ($str eq "+") {
	    if (scalar @args != 2) {
		&pSReply(".+host requires hostmask argument.");
		return;
	    }
	} elsif (scalar @args != 1) {
	    &pSReply("too many arguments.");
	    return;
	}

	if ($state) {			# adduser.
	    if (scalar @args == 1) {
		$args[1]	= &getHostMask($args[0]);
		if (!defined $args[1]) {
		    &ERROR("could not get hostmask?");
		    return;
		}
	    }

	    if ( &userAdd(@args) ) {	# success.
		&pSReply("Added $args[0]...");

	    } else {			# failure.
		&pSReply("User $args[0] already exists");
	    }

	} else {			# deluser.

	    if ( &userDel($args[0]) ) {	# success.
		&pSReply("Deleted $args[0] successfully.");

	    } else {			# failure.
		&pSReply("User $args[0] does not exist.");
	    }

	}
	return;
    }

    if ($message =~ /^sched$/) {
	my @list;
	my @run;

	my %time;
	foreach (keys %sched) {
	    next unless (exists $sched{$_}{TIME});
	    $time{ $sched{$_}{TIME}-time() }{$_} = 1;
	    push(@list,$_);

	    next unless (exists $sched{$_}{RUNNING});
	    push(@run,$_);
	}

	my @time;
	foreach (sort { $a <=> $b } keys %time) {
	    my $str = join(", ", sort keys %{ $time{$_} });
	    &DEBUG("time => $_, str => $str");
	    push(@time, "$str (".&Time2String($_).")");
	}

	&pSReply( &formListReply(0, "Schedulers: ", @time ) );
	&pSReply( &formListReply(0, "Scheds to run: ", sort @list ) );
	&pSReply( &formListReply(0, "Scheds running(should not happen?) ", sort @run ) );

	return;
    }

    return "REPLY";
}

1;
