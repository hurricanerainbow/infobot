#
# originally by kevin lenzo.
# revamped by the xk.
#

if (&IsParam("useStrict")) { use strict; }

sub IsFlag {
    my $flags = $_[0];
    my ($ret, $f, $o) = "";
    my @ind = split //, $flags;

    $userHandle ||= "default";

    &DEBUG("isFlag: userHandle == '$userHandle'.");

    foreach $f (split //, $userList{$userHandle}{'flags'}) {
	foreach $o (@ind) {
	    next unless ($f eq $o);

	    $ret = $f;
	    last;
	}
    }
    $ret;
}

sub verifyUser {
    my ($nick, $lnuh) = @_;
#    my ($n,$u,$h) = ($lnuh =~ /^(\S+)!(\S+)\@(\S+)$/);
    my ($user,$m);
    $userHandle = "default";

    ### FIXME: THIS NEEDS TO BE FIXED TO RECOGNISE HOSTMASKS!!!
    my $userinlist = "";
    foreach $user (keys %userList) {
	### Hack for time being.
	if (0) {
	    if ($user =~ /^\Q$nick\E$/i) {
		&DEBUG("vU: setting uH => '$user'.");
		$userHandle = $user;
		last;
	    }
	    next;
	} else {
	    $userinlist = $user if ($user =~ /^\Q$nick\E$/);
	}

	foreach $m (keys %{$userList{$user}{'mask'}}) {
	    $m =~ s/\?/./g;
	    $m =~ s/\*/.*?/g;
	    $m =~ s/([\@\(\)\[\]])/\\$1/g;

	    next unless ($lnuh =~ /^$m$/i);
	    &DEBUG("vUser: $lnuh matched masked ($m). Good!");

	    $userHandle = $user;
	    $userinlist = "";
	    last;
	}
	last if ($userHandle ne "");
    }

    if ($userinlist and $userHandle eq "") {
	&DEBUG("vUser: user is in list but wrong host.");
	$userHandle = $userinlist;
    }

#    $talkWho{$talkchannel} = $orig{who};
#    $talkWho = $orig{who};
### FIXME HERE.
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

1;
