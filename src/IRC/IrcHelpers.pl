#
# IrcHooks.pl: IRC Hooks stuff.
#      Author: dms
#     Version: 20010413
#     Created: 20010413
#        NOTE: Based on code by Kevin Lenzo & Patrick Cole  (c) 1997
#

if (&IsParam("useStrict")) { use strict; }

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
	    if ($mode =~ /[bov]/) {
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
    my $c	= "_default";
    if ($msgType =~ /public/i) {		# public.
	$floodwho = $c = lc $chan;
    } elsif ($msgType =~ /private/i) {	# private.
	$floodwho = lc $who;
    } else {				# dcc?
	&DEBUG("FIXME: floodwho = ???");
    }

    my $val = &getChanConfDefault("floodRepeat", "2:10", $c);
    my ($count, $interval) = split /:/, $val;

    # flood repeat protection.
    if ($addressed) {
	my $time = $flood{$floodwho}{$message} || 0;

	if ($msgType eq "public" and (time() - $time < $interval)) {
	    ### public != personal who so the below is kind of pointless.
	    my @who;
	    foreach (keys %flood) {
		next if (/^\Q$floodwho\E$/);
		next if (defined $chan and /^\Q$chan\E$/);

		push(@who, grep /^\Q$message\E$/i, keys %{ $flood{$_} });
	    }

	    return if ($lobotomized);

	    if (scalar @who) {
		&msg($who, "you already said what ".
				join(' ', @who)." have said.");
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
	} elsif ($msgType eq "private") {	# private.
	    &status("$b_cyan$who$ob is /msg'ing me");
	} else {				# public?
	    &status("$b_cyan$who$ob is addressing me");
	}

	$flood{$floodwho}{$message} = time();
    } elsif ($msgType eq "public" and &IsChanConf("kickOnRepeat")) {
	# unaddressed, public only.

	### TODO: use a separate "short-time" hash.
	my @data;
	@data	= keys %{ $flood{$floodwho} } if (exists $flood{$floodwho});
    }

    $val = &getChanConfDefault("floodMessages", "5:30", $c);
    ($count, $interval) = split /:/, $val;

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
	    &ignoreAdd("*!$uh", $chan, $expire, "flood overflow auto-detected.");
	    return;
	}

	$flood{$floodwho}{$message} = time();
    }

    my @ignore;
    if ($msgType =~ /public/i) {		    # public.
	$talkchannel	= $chan;
	&status("<$orig{who}/$chan> $orig{message}");
	push(@ignore, keys %{ $ignore{$chan} }) if (exists $ignore{$chan});
    } elsif ($msgType =~ /private/i) {		   # private.
	&status("[$orig{who}] $orig{message}");
	$talkchannel	= undef;
	$chan		= "_default";
    } else {
	&DEBUG("unknown msgType => $msgType.");
    }
    push(@ignore, keys %{ $ignore{"*"} }) if (exists $ignore{"*"});

    if ((!$skipmessage or &IsChanConf("seenStoreAll")) and
	&IsChanConf("seen") and
	$msgType =~ /public/
    ) {
	$seencache{$who}{'time'} = time();
	$seencache{$who}{'nick'} = $orig{who};
	$seencache{$who}{'host'} = $uh;
	$seencache{$who}{'chan'} = $talkchannel;
	$seencache{$who}{'msg'}  = $orig{message};
	$seencache{$who}{'msgcount'}++;
    }

    return if ($skipmessage);
    return unless (&IsParam("minVolunteerLength") or $addressed);

    foreach (@ignore) {
	s/\*/\\S*/g;

	next unless (eval { $nuh =~ /^$_$/i });

	&status("IGNORE <$who> $message");
	return;
    }

    if (defined $nuh) {
	if (!defined $userHandle) {
	    &DEBUG("line 1074: need verifyUser?");
	    &verifyUser($who, $nuh);
	}
    } else {
	&DEBUG("hookMsg: 'nuh' not defined?");
    }

### For extra debugging purposes...
    if ($_ = &process()) {
#	&DEBUG("IrcHooks: process returned '$_'.");
    }

    return;
}

sub chanLimitVerify {
    my($chan)	= @_;
    my $l	= $channels{$chan}{'l'};

    # only change it if it's not set.
    if (defined $l and &IsChanConf("chanlimitcheck")) {
	my $plus  = &getChanConfDefault("chanlimitcheckPlus", 5, $chan);
	my $count = scalar(keys %{ $channels{$chan}{''} });
	my $int   = &getChanConfDefault("chanlimitcheckInterval", 10, $chan);

	my $delta = $count + $plus - $l;
	$delta    =~ s/^\-//;

	if ($plus <= 3) {
	    &WARN("clc: stupid to have plus at $plus, fix it!");
	}

	if (exists $cache{ "chanlimitChange_$chan" }) {
	    if (time() - $cache{ "chanlimitChange_$chan" } < $int*60) {
		return;
	    }
	}

	### todo: check if we have ops.
	### todo: if not, check if nickserv/chanserv is avail.
	### todo: unify code with chanlimitcheck()
	if ($delta > 5) {
	    &status("clc: big change in limit; changing.");
	    &rawout("MODE $chan +l ".($count+$plus) );
	    $cache{ "chanlimitChange_$chan" } = time();
	}
    }
}

1;
