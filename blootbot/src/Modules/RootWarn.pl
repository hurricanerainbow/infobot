#
# RootWarn.pl: Warn people about usage of root on IRC.
#      Author: dms
#     Version: v0.3 (20000923)
#     Created: 19991008
#

use strict;

sub rootWarn {
    my ($nick,$user,$host,$chan) = @_;
    my $attempt = &dbGet("rootwarn", "nick", lc($nick), "attempt") || 0;
    my $warnmode	= &getChanConf("rootWarnMode");

    if ($attempt == 0) {	# first timer.
	if ($warnmode =~ /aggressive/i) {
	    &status(">>> Detected root user; notifying nick and channel.");
	    rawout("PRIVMSG $chan :R".("O" x int(rand 80 + 2))."T has landed!");
	} else {
	    &status(">>> Detected root user; notifying user");
	}

	if ($_ = &getFactoid("root")) {
	    &msg($nick, "root is $_");
	} else {
	    &status("root needs to be defined in database.");
	}

    } elsif ($attempt < 2) {	# 2nd/3rd time occurrance.
	&status("RootWarn: not first time root user; msg'ing $nick.");
	if ($_ = &getFactoid("root again")) {
	    &msg($nick, $_);
	} else {
	    &status("root again needs to be defined in database.");
	}

    } else {			# >3rd time occurrance.
	if ($warnmode =~ /aggressive/i) {
	    if ($channels{$chan}{'o'}{$ident}) {
		&status("RootWarn: $nick... sigh... bye bye.");
		rawout("MODE $chan +b *!root\@$host");	# ban
		&kick($chan,$nick,"bye bye");
	    }
	}
    }

    $attempt++;
    ### TODO: OPTIMIZE THIS.
    &dbSet("rootwarn", "nick", lc($nick), "attempt", $attempt);
    &dbSet("rootwarn", "nick", lc($nick), "time", time());
    &dbSet("rootwarn", "nick", lc($nick), "host", $user."\@".$host);
    &dbSet("rootwarn", "nick", lc($nick), "channel", $chan);

    return;
}

# Extras function.
sub CmdrootWarn {
    my $reply;
    my $count = &countKeys("rootwarn");

    if ($count == 0) {
	&performReply("no-one has been warned about root, woohoo");
	return;
    }

    # reply #1.
    $reply = "there ".&fixPlural("has",$count) ." been \002$i\002 ".
		&fixPlural("rooter",$count) ." warned about root.";

    if ($param{'DBType'} !~ /^mysql$/i) {
	&FIXME("rootwarn does not yet support non-mysql.");
	return;
    }

    # reply #2.
    $found = 0;
    my $query = "SELECT attempt FROM rootwarn WHERE attempt > 2";
    my $sth = $dbh->prepare($query);
    $sth->execute;

    while (my @row = $sth->fetchrow_array) {
	$found++;
    }

    $sth->finish;

    if ($found) {
	$reply .= " Of which, \002$found\002 ".
		&fixPlural("rooter",$found)." ".
		&fixPlural("has",$found).
		" done it at least 3 times.";
    }

    &performStrictReply($reply);
}

1;
