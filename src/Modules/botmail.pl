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

    if ($what =~ /^(for|add)\s+(.*)$/i) {
	&add( split(/\s+/, $2, 2) );

    } elsif ($what =~ /^check(\s+(.*))?$/i) {
	&check( split(/\s+/, $1, 2) );

    } elsif ($what =~ /^(read|next)$/i) {
	# TODO: read specific items? nah, will make this too complex.
	&next($::who);

    }
}

#####
# Usage: botmail::check($recipient)
sub check {
    my($recipient) = @_;
    $recipient ||= $::who;

    # todo: simplify this select (use a diff function)
    my @from = &::dbGet("botmail", "srcwho",
	"dstwho=".&::dbQuote(lc $recipient)
    );
    my $t	= scalar @from;
    my $from	= join(", ", @from);

    if ($t == 0) {
	&::msg($recipient, "You have no botmail.");
    } else {
	&::msg($recipient, "You have $t messages awaiting, from: $from");
    }
}

#####
# Usage: botmail::next($recipient)
sub next {
    my($recipient) = @_;

    my %hash = &::dbGetColNiceHash("botmail", "*",
	"dstwho=".&::dbQuote(lc $recipient)
    );

    if (scalar (keys %hash) <= 1) {
	&::msg($recipient, "You have no botmail.");
    } else {
	my $ago = &::Time2String(time() - $hash{'time'});
	&::msg($recipient, "From $hash{srcwho} ($hash{srcuh}) on $hash{time} [$ago]:");
	&::msg($recipient, $hash{'msg'});
	#&::dbDel("botmail", "id", $hash{id});
    }
}

#####
# Usage: botmail::add($recipient, $msg)
sub add {
    my($recipient, $msg) = @_;
    &::DEBUG("botmail::add(@_)");

    if (lc $recipient eq $::who) {
	&::msg($::who, "well... a botmail to oneself is stupid!");
	return;
    }

    # only support 1 botmail with unique dstwho/srcwho to have same
    # functionality as botmail from infobot.
    my %hash = &::dbGetColNiceHash("botmail", "*",
	"srcwho=".&::dbQuote(lc $::who)." AND ".
	"dstwho=".&::dbQuote(lc $recipient)
    );

    if (scalar (keys %hash) > 1) {
	&::msg($::who, "$recipient already has a message queued from you");
	return;
    }

    &::dbSet("botmail", {
	'dstwho'	=> lc $recipient,
	'srcwho'	=> lc $::who,
    }, {
	'srcuh'	=> $::nuh,	# will this work?
	'time'	=> time(),
	'msg'	=> $msg,
    } );

    &::msg($::who, "OK, $::who, I'll let $recipient know.");
}

1;
