#
# CLI/Support.pl: Stubs for functions that are from IRC/*
#         Author: Tim Riker <Tim@Rikers.org>
#        Version: v0.1 (20021028)
#        Created: 20021028
#

sub msg {
    my ($nick, $msg) = @_;
    if (!defined $nick) {
	&ERROR("msg: nick == NULL.");
	return;
    }

    if (!defined $msg) {
	$msg ||= "NULL";
	&WARN("msg: msg == $msg.");
	return;
    }

    &status(">$nick< $msg");

    print("$nick: $msg\n");
}

sub performStrictReply {
    &msg($who, @_);
}

sub performReply {
    &msg($who, @_);
}

sub performAddressedReply {
    return unless ($addressed);
    &msg($who, @_);
}

sub pSReply {
    &msg($who, @_);
}

1;
