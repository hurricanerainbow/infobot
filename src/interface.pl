#
# interface.pl:
#       Author:
#

# use strict;	# TODO

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

    # install libterm-readline-gnu-perl to get history support
    use Term::ReadLine;
    $term = new Term::ReadLine 'blootbot';
    $prompt = "$who> ";
    #$OUT = $term->OUT || STDOUT;
    while ( defined ($_ = $term->readline($prompt)) ) {
	$orig{message} = $_;
	$message = $_;
	chomp $message;
	last if ($message =~ m/^quit$/);
	$_ = &process() if $message;
    }
    &doExit();
}

1;
