#
# DynaConfig.pl: Read/Write configuration files dynamically.
#        Author: dms
#       Version: v0.1 (20010120)
#       Created: 20010119
#	   NOTE: Merged from User.pl
#

if (&IsParam("useStrict")) { use strict; }

#####
##### USERFILE CONFIGURATION READER/WRITER
#####

sub readUserFile {
    if (!open IN,"$bot_misc_dir/blootbot.users") {
	&ERROR("cannot read userfile.");
	&closeLog();
	exit 1;
    }

    undef %users;	# clear on reload.
    undef %bans;	# reset.
    undef %ingore;	# reset.

    my $ver = <IN>;
    if ($ver !~ /^#v1/) {
	&ERROR("old or invalid user file found.");
	&closeLog();
	exit 1;	# correct?
    }

    my $nick;
    my $type;
    while (<IN>) {
	chop;

	next if /^$/;
	next if /^#/;

	if (/^--(\S+)[\s\t]+(.*)$/) {		# user: middle entry.
	    my ($what,$val) = ($1,$2);

	    if (!defined $val or $val eq "") {
		&WARN("$what: val == NULL.");
		next;
	    }

	    # nice little hack.
	    if ($what eq "HOSTS") {
		$users{$nick}{$what}{$val} = 1;
	    } else {
		$users{$nick}{$what} = $val;
	    }

	} elsif (/^(\S+)$/) {			# user: start entry.
	    $nick	= $1;

	} elsif (/^::(\S+) ignore$/) {		# ignore: start entry.
	    $chan	= $1;
	    $type	= "ignore";

	} elsif (/^- (\S+):\+(\d+):\+(\d+):(\S+):(.*)$/ and $type eq "ignore") {
	    ### ignore: middle entry.
	    my $mask = $1;
	    my(@array) = ($2,$3,$4,$5);
	    ### DEBUG purposes only!
	    if ($mask !~ /^$mask{nuh}$/) {
		&WARN("ignore: mask $mask is invalid.");
		next;
	    }
	    $ignore{$chan}{$mask} = \@array;

	} elsif (/^::(\S+) bans$/) {		# bans: start entry.
	    $chan	= $1;
	    $type	= "bans";

	} elsif (/^- (\S+):\+(\d+):\+(\d+):(\d+):(\S+):(.*)$/ and $type eq "bans") {
	    ### bans: middle entry.
	    # $btime, $atime, $count, $whoby, $reason.
	    my(@array) = ($2,$3,$4,$5,$6);
	    $bans{$chan}{$1} = \@array;

	} else {				# unknown.
	    &WARN("unknown line: $_");
	}
    }
    close IN;

    &status( sprintf("USERFILE: Loaded: %d users, %d bans, %d ignore",
		scalar(keys %users)-1,
		scalar(keys %bans),		# ??
		scalar(keys %ignore),		# ??
	)
    );
}

sub writeUserFile {
    if (!open OUT,">$bot_misc_dir/blootbot.users") {
	&ERROR("cannot write to userfile.");
	return;
    }

    my $time		= scalar(localtime);

    print OUT "#v1: blootbot -- $ident -- written $time\n\n";

    ### USER LIST.
    my $cusers	= 0;
    foreach (sort keys %users) {
	my $user = $_;
	$cusers++;
	my $count = scalar keys %{ $users{$user} };
	if (!$count) {
	    &WARN("user $user has no other attributes; skipping.");
	    next;
	}

	print OUT "$user\n";

	foreach (sort keys %{ $users{$user} }) {
	    my $what	= $_;
	    my $val	= $users{$user}{$_};

	    if (ref($val) eq "HASH") {
		foreach (sort keys %{ $users{$user}{$_} }) {
		    print OUT "--$what\t\t$_\n";
		}

	    } else {
		print OUT "--$_\t\t$val\n";
	    }
	}
	print OUT "\n";
    }

    ### BAN LIST.
    my $cbans	= 0;
    foreach (keys %bans) {
	my $chan = $_;
	$cbans++;

	my $count = scalar keys %{ $bans{$chan} };
	if (!$count) {
	    &WARN("bans: chan $chan has no other attributes; skipping.");
	    next;
	}

	print OUT "::$chan bans\n";
	foreach (keys %{ $bans{$chan} }) {
# format: bans: mask expire time-added count who-added reason
	    my @array = @{ $bans{$chan}{$_} };
	    if (scalar @array != 5) {
		&WARN("bans: $chan/$_ is corrupted.");
		next;
	    }

	    printf OUT "- %s:+%d:+%d:%d:%s:%s\n", $_, @array;
	}
    }
    print OUT "\n" if ($cbans);

    ### IGNORE LIST.
    my $cignore	= 0;
    foreach (keys %ignore) {
	my $chan = $_;
	$cignore++;

	my $count = scalar keys %{ $ignore{$chan} };
	if (!$count) {
	    &WARN("ignore: chan $chan has no other attributes; skipping.");
	    next;
	}

	### TODO: use hash instead of array for flexibility?
	print OUT "::$chan ignore\n";
	foreach (keys %{ $ignore{$chan} }) {
# format: ignore: mask expire time-added who-added reason
	    my @array = @{ $ignore{$chan}{$_} };
	    if (scalar @array != 4) {
		&WARN("ignore: $chan/$_ is corrupted.");
		next;
	    }

	    printf OUT "- %s:+%d:+%d:%s:%s\n", $_, @array;
	}
    }

    close OUT;

    $wtime_userfile = time();
    &status("--- Saved USERFILE ($cusers users; $cbans bans; $cignore ignore) at $time");
    if (defined $msgType and $msgType =~ /^chat$/) {
	&performStrictReply("--- Writing user file...");
    }
}

#####
##### CHANNEL CONFIGURATION READER/WRITER
#####

sub readChanFile {
    if (!open IN,"$bot_misc_dir/blootbot.chan") {
	&ERROR("cannot erad chanfile.");
	return;
    }

    undef %chanconf;	# reset.

    $_ = <IN>;		# version string.

    my $chan;
    while (<IN>) {
	chop;

	next if /^$/;

	if (/^(\S+)\s*$/) {
	    $chan	= $1;
	    next;
	}
	next unless (defined $chan);

	if (/^[\s\t]+\+(\S+)$/) {		# bool, true.
	    $chanconf{$chan}{$1} = 1;

	} elsif (/^[\s\t]+\-(\S+)$/) {		# bool, false.
	    $chanconf{$chan}{$1} = 0;

	} elsif (/^[\s\t]+(\S+)[\ss\t]+(.*)$/) {# what = val.
	    $chanconf{$chan}{$1} = $2;

	} else {
	    &WARN("unknown line: $_") unless (/^#/);
	}
    }
    close IN;

    # verify configuration
    ### TODO: check against valid params.
    foreach $chan (keys %chanconf) {
	foreach (keys %{ $chanconf{$chan} }) {
	    next unless (/^[+-]/);
	    &WARN("invalid param: chanconf{$chan}{$_}; removing.");
	    delete $chanconf{$chan}{$_};
	    undef $chanconf{$chan}{$_};
	}
    }

    &status("CHANFILE: Loaded: ".(scalar(keys %chanconf)-1)." chans");
}

sub writeChanFile {
    if (!open OUT,">$bot_misc_dir/blootbot.chan") {
	&ERROR("cannot write chanfile.");
	return;
    }

    my $time		= scalar(localtime);
    print OUT "#v1: blootbot -- $ident -- written $time\n\n";

    if ($flag_quit) {

	### Process 1: if defined in _default, remove same definition
	###		from non-default channels.
	foreach (keys %{ $chanconf{_default} }) {
	    my $opt	= $_;
	    my $val	= $chanconf{_default}{$opt};
	    my @chans;

	    foreach (keys %chanconf) {
		$chan = $_;

		next if ($chan eq "_default");
		next unless (exists $chanconf{$chan}{$opt});
		next unless ($val eq $chanconf{$chan}{$opt});
		push(@chans,$chan);
		delete $chanconf{$chan}{$opt};
	    }

	    if (scalar @chans) {
		&DEBUG("Removed config $opt to @chans since it's defiend in '_default'");
	    }
	}

	### Process 2: if defined in all chans but _default, set in
	###		_default and remove all others.
	my (%optsval, %opts);
	foreach (keys %chanconf) {
	    $chan = $_;
	    next if ($chan eq "_default");
	    my $opt;

	    foreach (keys %{ $chanconf{$chan} }) {
		$opt = $_;
		if (exists $optsval{$opt} and $optsval{$opt} eq $chanconf{$chan}{$opt}) {
		    $opts{$opt}++;
		    next;
		}
		$optsval{$opt}	= $chanconf{$chan}{$opt};
		$opts{$opt}	= 1;
	    }
	}

	&DEBUG("chans => ".scalar(keys %chanconf)." - 1");
	foreach (keys %opts) {
	    &DEBUG("  opts{$_} => $opts{$_}");
	}

	### other optimizations are in UserDCC.pl
    }

    ### lets do it...
    foreach (sort keys %chanconf) {
	$chan	= $_;

	print OUT "$chan\n";

	foreach (sort keys %{ $chanconf{$chan} }) {
	    my $val = $chanconf{$chan}{$_};

	    if ($val =~ /^0$/) {		# bool, false.
		print OUT "    -$_\n";

	    } elsif ($val =~ /^1$/) {		# bool, true.
		print OUT "    +$_\n";

	    } else {				# what = val.
		print OUT "    $_ $val\n";

	    }

	}
	print OUT "\n";
    }

    close OUT;

    $wtime_chanfile = time();
    &status("--- Saved CHANFILE (".scalar(keys %chanconf).
		" chans) at $time");

    if (defined $msgType and $msgType =~ /^chat$/) {
	&performStrictReply("--- Writing chan file...");
    }
}

#####
##### USER COMMANDS.
#####

sub IsFlag {
    my $flags = shift;
    my ($ret, $f, $o) = "";

    &verifyUser($who, $nuh);

    foreach $f (split //, $users{$userHandle}{FLAGS}) {
	foreach $o ( split //, $flags ) {
	    next unless ($f eq $o);

	    $ret = $f;
	    last;
	}
    }

    $ret;
}

sub verifyUser {
    my ($nick, $lnuh) = @_;
    my ($user,$m);

    if ($userHandle = $dcc{'CHATvrfy'}{$who}) {
	&VERB("vUser: cached auth for $who.",2);
	return $userHandle;
    }

    $userHandle = "";

    foreach $user (keys %users) {
	next if ($user eq "_default");

	foreach $m (keys %{$users{$user}{HOSTS}}) {
	    $m =~ s/\?/./g;
	    $m =~ s/\*/.*?/g;
	    $m =~ s/([\@\(\)\[\]])/\\$1/g;

	    next unless ($lnuh =~ /^$m$/i);

	    if ($user !~ /^\Q$nick\E$/i and !exists $cache{VUSERWARN}{$user}) {
		&status("vU: host matched but diff nick ($nick != $user).");
		$cache{VUSERWARN}{$user} = 1;
	    }

	    $userHandle = $user;
	    last;
	}

	last if ($userHandle ne "");

	if ($user =~ /^\Q$nick\E$/i and !exists $cache{VUSERWARN}{$user}) {
	    &status("vU: nick matched but host is not in list ($lnuh).");
	    $cache{VUSERWARN}{$user} = 1;
	}
    }

    $userHandle ||= "_default";
    # what's talkchannel for?
    $talkWho{$talkchannel} = $who if (defined $talkchannel);
    $talkWho = $who;

    return $userHandle;
}

sub ckpasswd {
    # returns true if arg1 encrypts to arg2
    my ($plain, $encrypted) = @_;
    if ($encrypted eq "") {
	($plain, $encrypted) = split(/\s+/, $plain, 2);
    }
    return 0 unless ($plain ne "" and $encrypted ne "");

    # MD5 // DES. Bobby Billingsley++.
    my $salt = substr($encrypted, 0, 2);
    if ($encrypted =~ /^\$\d\$(\w\w)\$/) {
	$salt = $1;
    }

    return ($encrypted eq crypt($plain, $salt));
}

# mainly for dcc chat... hrm.
sub hasFlag {
    my ($flag) = @_;

    if (&IsFlag($flag) eq $flag) {
	return 1;
    } else {
	&status("DCC CHAT: <$who> $message -- not enough flags.");
	&performStrictReply("error: you do not have enough flags for that. ($flag required)");
	return 0;
    }
}

sub ignoreAdd {
    my($mask,$chan,$expire,$comment) = @_;

    $chan	||= "*";	# global if undefined.
    $comment	||= "";		# optional.
    $expire	||= 0;		# permament.
    my $count	||= 0;

    if ($expire > 0) {
	$expire		= $expire*60 + time();
    } else {
	$expire		= 0;
    }

    my $exist	= 0;
    $exist++ if (exists $ignore{$chan}{$mask});

    $ignore{$chan}{$mask} = [$expire, time(), $who, $comment];

    if ($exist) {
	$utime_userfile = time();
	$ucount_userfile++;

	return 2;
    } else {
	return 1;
    }
}

sub ignoreDel {
    my($mask)	= @_;
    my @match;

    ### TODO: support wildcards.
    foreach (keys %ignore) {
	my $chan = $_;

	foreach (grep /^\Q$mask\E$/i, keys %{ $ignore{$chan} }) {
	    delete $ignore{$chan}{$mask};
	    push(@match,$chan);
	}

	&DEBUG("iD: scalar => ".scalar(keys %{ $ignore{$chan} }) );
    }

    if (scalar @match) {
	$utime_userfile = time();
	$ucount_userfile++;
    }

    return @match;
}

sub userAdd {
    my($nick,$mask)	= @_;

    if (exists $users{$nick}) {
	return 0;
    }

    $utime_userfile = time();
    $ucount_userfile++;

    $users{$nick}{HOSTS}{$mask} = 1;
    $users{$nick}{FLAGS}	||= $users{_default}{FLAGS};

    return 1;
}

sub userDel {
    my($nick)	= @_;

    if (!exists $users{$nick}) {
	return 0;
    }

    $utime_userfile = time();
    $ucount_userfile++;

    delete $users{$nick};

    return 1;
}

sub banAdd {
    my($mask,$chan,$expire,$reason) = @_;

    $chan	||= "*";
    $expire	||= 0;

    if ($expire > 0) {
	$expire		= $expire*60 + time();
    }

    my $exist	= 1;
    $exist++ if (exists $bans{$chan}{$mask} or
		exists $bans{'*'}{$mask});
    $bans{$chan}{$mask} = [$expire, time(), 0, $who, $reason];

    if ($exist == 1) {
	$utime_userfile = time();
	$ucount_userfile++;
    }

    return $exist;
}

sub banDel {
    my($mask)	= @_;
    my @match;

    foreach (keys %bans) {
	my $chan	= $_;

	foreach (grep /^\Q$mask\E$/i, keys %{ $bans{$chan} }) {
	    delete $bans{$chan}{$_};
	    push(@match, $chan);
	}

	&DEBUG("bans: scalar => ".scalar(keys %{ $bans{$chan} }) );
    }

    if (scalar @match) {
	$utime_userfile = time();
	$ucount_userfile++;
    }

    return @match;
}

sub IsUser {
    my($user) = @_;

    if ( &getUser($user) ) {
	return 1;
    } else {
	return 0;
    }
}

sub getUser {
    my($user) = @_;

    if (!defined $user) {
	&WARN("getUser: user == NULL.");
	return;
    }

    if (my @retval = grep /^\Q$user\E$/i, keys %users) {
	if ($retval[0] ne $user) {
	    &WARN("getUser: retval[0] ne user ($retval[0] ne $user)");
	}
	my $count = scalar keys %{ $users{$retval[0]} };
	&DEBUG("count => $count.");

	return $retval[0];
    } else {
	return;
    }
}

sub chanSet {
    my($cmd, $chan, $what, $val) = @_;

    if ($cmd eq "+chan") {
	if (exists $chanconf{$chan}) {
	    &pSReply("chan $chan already exists.");
	    return;
	}
	$chanconf{$chan}{_time_added}	= time();
	$chanconf{$what}{autojoin}	= 1;

	&pSReply("Joining $chan...");
	&joinchan($chan);

	return;
    }

    if (!exists $chanconf{$chan}) {
	&pSReply("no such channel $chan");
	return;
    }

    my $update	= 0;

    if (defined $what and $what =~ s/^\+(\S+)/$1/) {
	my $was	= $chanconf{$chan}{$1};
	if (defined $was and $was eq "1") {
	    &pSReply("setting $what for $chan already 1.");
	    return;
	}

	$was	= ($was) ? "; was '$was'" : "";
	&pSReply("Setting $what for $chan to '1'$was.");

	$chanconf{$chan}{$what} = 1;

	$update++;
    } elsif (defined $what and $what =~ s/^\-(\S+)/$1/) {
	my $was	= $chanconf{$chan}{$1};
	# hrm...
	if (!defined $was) {
	    &pSReply("setting $what for $chan is not set.");
	    return;
	}

	if ($was eq "0") {
	    &pSReply("setting $what for $chan already 0.");
	    return;
	}

	$was	= ($was) ? "; was '$was'" : "";
	&pSReply("Setting $what for $chan to '0'$was.");

	$chanconf{$chan}{$what} = 0;

	$update++;
    } elsif (defined $val) {
	my $was	= $chanconf{$chan}{$what};
	if (defined $was and $was eq $val) {
	    &pSReply("setting $what for $chan already '$val'.");
	    return;
	}
	$was	= ($was) ? "; was '$was'" : "";
	&pSReply("Setting $what for $chan to '$val'$was.");

	$chanconf{$chan}{$what} = $val;

	$update++;
    } else {				# read only.
	if (exists $chanconf{$chan}{$what}) {
	    &pSReply("$what for $chan is '$chanconf{$chan}{$what}'");
	} else {
	    &pSReply("$what for $chan is not set.");
	}
    }

    if ($update) {
	$utime_chanfile = time();
	$ucount_chanfile++;
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

    return;
}

my @regFlagsChan = (
	"autojoin",
	"freshmeat",
	"limitcheckInterval",
	"limitcheckPlus",
	"allowConv",
	"allowDNS",
### TODO: finish off this list.
);

my @regFlagsUser = ("mno");	# todo...

1;
