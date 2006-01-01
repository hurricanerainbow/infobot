#
# OnJoin.pl: emit a message when a user enters the channel
#    Author: tensai
#   Version: v0.1
#   Created: 20051222
#   Updated: 20051230

use strict;

use vars qw(%channels %param);
use vars qw($dbh $who $chan);

sub onjoin {
	my ($nick, $user, $host, $chan) = @_;
	my $n	= lc $nick;
	my $message = &sqlSelect('onjoin', 'message', { nick => $n, channel => $chan } ) || 0;

	# print the message, if there was one
	if ($message){
		&status("OnJoin: $nick arrived");
		&msg($chan, $message);
	}

	return;
}

# set and get messages
sub Cmdonjoin {
	my $msg = shift;
	$msg =~ m/(.*?)( (.*))/;
	my $nick = $1;
	$msg = $3;

	# if msg not set, show what the message would be
	if (!$msg){
		$nick = $who if (!$nick);
		$msg = &sqlSelect('onjoin', 'message', { nick => $nick, channel => $chan } ) || '';
		if ($msg){
			&performReply($msg);
		}
		return;
	}

	# get params
	my $strict = &getChanConf('onjoinStrict');
	my $ops = &getChanConf('onjoinOpsOnly');

	# only allow changes by ops
	if ($ops){
		if (!$channels{$chan}{o}{$who}){
			&performReply("sorry, you're not an operator");
			return;
		}
	}
	# only allow people to change their own message (superceded by OpsOnly)
	elsif ($strict){
		# regardless of strict mode, ops can always change
		if (!$channels{$chan}{o}{$who} and $nick ne $who){
			&performReply("I can't alter a message for another user (strict mode)");
			return;
		}
	}

	&sqlDelete('onjoin', { nick => $nick, channel => $chan});
	&sqlInsert('onjoin', { nick => $nick, channel => $chan, message => $msg});
	&performReply("ok");
	return;
}

1;
