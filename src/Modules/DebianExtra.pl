#
#  DebianExtra.pl: Extra stuff for debian
#          Author: xk <xk@leguin.openprojects.net>
#         Version: v0.1 (20000520)
#         Created: 20000520
#

use strict;

my $bugs_url = "http://master.debian.org/~wakkerma/bugs";

sub debianBugs {
    my @results = &main::getURL($bugs_url);
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

	&main::performStrictReply(
		"Debian bugs statistics, last updated on $date... ".
		"There are \002$rcbugs\002 release-critical bugs;  $xtxt".
		"\002$bugs_closed\002 bugs closed, opening \002$bugs_opened\002 bugs.  ".
		"About \002$remove\002 packages will be removed."
	);
    } else {
	&main::msg($main::who, "Couldn't retrieve data for debian bug stats.");
    }
}

1;
