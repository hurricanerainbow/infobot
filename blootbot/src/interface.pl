#
# interface.pl:
#
#       Author:
#

#use strict;

sub whatInterface {
    if (!&IsParam("Interface") or $param{'Interface'} =~ /IRC/) {
	return "IRC";
    } else {
	return "CLI";
    }
}

sub cliloop {
    &status("Using CLI...");
    &status("Now type what you want.");

    $nuh = "local!local\@local";
    $uh  = "local\@local";
    $who = "local";
    $orig{who} = "local";
    $ident = $param{'ircNick'};
    $chan = $talkchannel = "_local";
    $addressed = 1;
    $msgType = 'public';

    print ">>> ";
    while (<STDIN>) {
	$orig{message} = $_;
	$message = $_;
	chomp $message;
	$_ = &process() if $message;
	print ">>> ";
    }
}

1;
