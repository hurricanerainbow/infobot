#
# originally by kevin lenzo.
# revamped by the xk.
#

if (&IsParam("useStrict")) { use strict; }

sub IsFlag {
    my $flags = shift;
    my ($ret, $f, $o) = "";

    foreach $f (split //, $userList{$userHandle}{'flags'}) {
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

    foreach $user (keys %userList) {
	foreach $m (keys %{$userList{$user}{'mask'}}) {
	    $m =~ s/\?/./g;
	    $m =~ s/\*/.*?/g;
	    $m =~ s/([\@\(\)\[\]])/\\$1/g;

	    next unless ($lnuh =~ /^$m$/i);

	    if ($user !~ /^\Q$nick\E$/i) {
		&status("vU: host matched but diff nick ($nick != $user).");
	    }

	    $userHandle = $user;
	    last;
	}

	last if ($userHandle ne "");

	if ($user =~ /^\Q$nick\E$/i) {
	    &status("vU: nick matched but host is not in list ($lnuh).");
	}
    }

    $userHandle ||= "default";
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
