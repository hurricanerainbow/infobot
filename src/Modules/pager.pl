# Pager
#
# modified from pager.pm in flooterbuck

package pager;
use strict;

my $no_page;

BEGIN {
	eval qq{
		use Mail::Mailer qw(sendmail);
	};
	$no_page++ if ($@);
}

sub pager::page {
	my ($message) = @_;
	my ($retval);
	if ($no_page) {
		&main::status("page module requires Mail::Mailer.");
		return 'page module not active';
	}
	unless ($message =~ /^(\S+)\s+(.*)$/) {
		return undef;
	}

	my $from = $::who;
	my $to = $1;
	my $msg = $2;

	my $tofactoid = &::getFactoid("${to}'s pager");
	if ($tofactoid =~ /(\S+@\S+)/) {
		my $toaddr = $1;
		$toaddr =~ s/^mailto://;

		my $fromfactoid = &::getFactoid("${from}'s pager");

		my $fromaddr;
		if ($fromfactoid =~ /(\S+@\S+)/) {
			$fromaddr = $1;
			$fromaddr =~ s/^mailto://;
		} else {
			$fromaddr = 'infobot@example.com';
		}

		my $channel = $::chan || 'infobot';

		&main::status("pager: from $from <$fromaddr>, to $to <$toaddr>, msg \"$msg\"");
		my %headers = (
			To => "$to <$toaddr>",
			From => "$from <$fromaddr>",
			Subject => "Message from $channel!",
			'X-Mailer' => "blootbot",
		);

		#my $logmsg;
		#for (keys %headers) {
		#	$logmsg .= "$_: $headers{$_}\n";
		#}
		#$logmsg .= "\n$msg\n";
		#&main::status("pager:\n$logmsg");

		my $failed;
		my $mailer = new Mail::Mailer 'sendmail';
		$failed++ unless $mailer->open(\%headers);
		$failed++ unless print $mailer "$msg\n";
		$failed++ unless $mailer->close;

		if ($failed) {
			$retval='Sorry, an error occurred while sending mail.';
		} else {
			$retval="$from: I sent mail to $toaddr.";
		}
	} else {
		$retval="Sorry, I don't know ${to}'s email address.";
	}
	&::performStrictReply($retval);
}

"pager";
# vim: ts=2 sw=2
