#
#  botmail.pl: Botmail (ala in infobot)
#      Author: dms
#     Version: v0.1 (20021122).
#     Created: 20021122
#	 NOTE: Motivated by BZFlag.
#        TODO: full-fledged notes services (optional auth, etc)
#

package botmail;

use strict;

sub parse {
    my($what) = @_;

    if (!defined $what or $what =~ /^\s*$/) {
	&::help("botmail");
	return;
    }

    if ($what =~ /^add(\s+(.*))?$/i) {
	&add( split(/\s+/, $1, 2) );

    } elsif ($what =~ /^next$/i) {
	# todo: read specific items? nah, will make this too complex.
	&read($::who);

    }
}

#####
# Usage: botmail::check($who)
sub check {
    my($w) = @_;

    # todo: simplify this select (use a diff function)
    my @from = &::dbGet("botmail", "srcwho"
	"dstwho=".&::dbQuote(lc $w)
    );
    my $t	= scalar @from;
    my $from	= join(", ", @from);

    if ($t == 0) {
	&::msg($w, "You have no botmail.");
    } else {
	&::msg($w, "You have $t messages awaiting, from: $from");
    }
}

#####
# Usage: botmail::read($who)
sub read {
    my($w) = @_;

    # todo: simplify this select (use a diff function)
    my $H = &::dbSelectHashref("*", "botmail", "srcwho",
	"dstwho=".&::dbQuote(lc $w)
    );

    my $t = $H->total;	# possible?

    if ($t == 0) {
	&::msg($w, "You have no botmail.");
    } else {
	my $ago = &::Time2String(time() - $H->{time});
	&::msg($w, "From $H->{srcwho} ($H->{srcuh}) on $H->{time} [$ago]:");
	&::msg($w, $H->{message});
	&::dbDel("botmail", "id", $H->{id});
    }
}

#####
# Usage: botmail::add($who, $msg)
sub add {
    my($w, $msg) = @_;

    # todo: simplify this select (use a diff function)
    my $H = &::dbSelectHashref("*", "botmail", "srcwho",
	"srcwho=".&::dbQuote(lc $::who)." AND ".
	"dstwho=".&::dbQuote(lc $w)
    );

    my $t = $H->total;	# possible?

    # only support 1 botmail with unique dstwho/srcwho to have same
    # functionality as botmail from infobot.
    if ($t == 1) {
	&::msg($::who, "$w already has a message queued from you");
	return;
    }

    if (lc $w == $::who) {
	&::msg($::who, "well... a botmail to oneself is stupid!");
	return;
    }

    &::dbSetRow("botmail", {
	dstwho	=> lc $w,
	srcwho	=> lc $::who,
	srcuh	=> $::nuh{lc $w},	# will this work?
	-time	=> "NOW()",		# todo: add '-' support.
					# dbUpdate() supports it.
    } );

    &::msg($::who, "OK, $::who, I'll let $w know.");
}

1;
