#
#  DebianExtra.pl: Extra stuff for debian
#          Author: dms
#         Version: v0.1 (20000520)
#         Created: 20000520
#

use strict;

package DBugs;

sub Parse {
    my($args) = @_;

    if (!defined $args or $args =~ /^$/) {
	&debianBugs();
    }

    if ($args =~ /^(\d+)$/) {
	# package number:
	&do_id($args);

    } elsif ($args =~ /^(\S+\@\S+)$/) {
	# package email maintainer.
	&do_email($args);

    } elsif ($args =~ /^(\S+)$/) {
	# package name.
	&do_pkg($args);

    } else {
	# invalid.
	&::msg($::who, "error: could not parse $args");
    }
}

sub debianBugs {
    my @results = &::getURL("http://master.debian.org/~wakkerma/bugs");
    my ($date, $rcbugs, $remove);
    my ($bugs_closed, $bugs_opened) = (0,0);

    if (scalar @results) {
	foreach (@results) {
	    s/<.*?>//g;
	    $date   = $1 if (/status at (.*)\s*$/);
	    $rcbugs = $1 if (/bugs: (\d+)/);
	    $remove = $1 if (/REMOVE\S+ (\d+)\s*$/);
	    if (/^(\d+) r\S+ b\S+ w\S+ c\S+ a\S+ (\d+)/) {
		$bugs_closed = $1;
		$bugs_opened = $2;
	    }
	}
	my $xtxt = ($bugs_closed >=$bugs_opened) ?
			"It's good to see " :
			"Oh no, the bug count is rising -- ";

	&::performStrictReply(
		"Debian bugs statistics, last updated on $date... ".
		"There are \002$rcbugs\002 release-critical bugs;  $xtxt".
		"\002$bugs_closed\002 bugs closed, opening \002$bugs_opened\002 bugs.  ".
		"About \002$remove\002 packages will be removed."
	);
    } else {
	&::msg($::who, "Couldn't retrieve data for debian bug stats.");
    }
}

sub do_id {
    my($num)	= @_;
    my $url	= "http://bugs.debian.org/$num";

    if (1) { # FIXME
	&::msg($::who, "do_id not supported yet.");
	return;
    }

    my @results = &::getURL($url);
    foreach (@results) {
	&::DEBUG("do_id: $_");
    }
}

sub do_email {
    my($email)	= @_;
    my $url	= "http://bugs.debian.org/$email";

    if (1) { # FIXME
	&::msg($::who, "do_email not supported yet.");
	return;
    }

    my @results = &::getURL($url);
    foreach (@results) {
	&::DEBUG("do_email: $_");
    }
}

sub do_pkg {
    my($pkg)	= @_;
    my $url	= "http://bugs.debian.org/$pkg";

    if (1) { # FIXME
	&::msg($::who, "do_pkg not supported yet.");
	return;
    }

    my @results = &::getURL($url);
    foreach (@results) {
	&::DEBUG("do_pkg: $_");
    }
}

1;
