#
#   spell.pl: interface to aspell/ispell/spell
#	 Author: Tim Riker <Tim@Rikers.org>
#	 Source: extracted from UserExtra
#  Licensing: Artistic License (as perl itself)
#	Version: v0.1
#
#  Copyright (c) 2005 Tim Riker
#

package spell;

use strict;

sub spell::spell {
	my $query = shift;
	my $binary;
	my @binaries = (
		'/usr/bin/aspell',
		'/usr/bin/ispell',
		'/usr/bin/spell'
	);

	foreach (@binaries) {
		if (-x $_) {
			$binary=$_;
			last;
		}
	}

	if (!$binary) {
		return("no binary found.");
	}

	if (!&main::validExec($query)) {
		return("argument appears to be fuzzy.");
	}

	my $reply = "I can't find alternate spellings for '$query'";

	foreach (`/bin/echo '$query' | $binary -a -S`) {
		chop;
		last if !length;		# end of query.

		if (/^\@/) {		# intro line.
			next;
		} elsif (/^\*/) {		# possibly correct.
			$reply = "'$query' may be spelled correctly";
			last;
		} elsif (/^\&/) {		# possible correction(s).
			s/^\& (\S+) \d+ \d+: //;
			my @array = split(/,? /);

			$reply = "possible spellings for $query: @array";
			last;
		} elsif (/^\+/) {
			&main::DEBUG("spell: '+' found => '$_'.");
			last;
		} elsif (/^# (.*?) 0$/) {
			# none found.
			last;
		} else {
			&main::DEBUG("spell: unknown: '$_'.");
		}
	}

	return($reply);
}

sub spell::query {
	&::performStrictReply(&spell(@_));
	return;
}

1;
# vim: ts=2 sw=2
