###
### Reply.pl: Kevin Lenzo   (c) 1997
###

##
# x is y === $lhs $mhs $rhs
#
#   lhs - factoid.
#   mhs - verb.
#   rhs - factoid message.
##

if (&IsParam("useStrict")) { use strict; }

use vars qw($msgType $uh $lastWho $ident);
use vars qw(%lang %lastWho);

sub getReply {
    my($message) = @_;
    my($lhs,$mhs,$rhs);
    my($result,$reply);
    my $literal = 0;
    $orig{message} = $message;

    if (!defined $message or $message =~ /^\s*$/) {
	&WARN("getR: message == NULL.");
	return '';
    }

    $message =~ tr/A-Z/a-z/;

    if ($result = &getFactoid($message)) {
	$lhs = $message;
	$mhs = "is";
	$rhs = $result;
    } else {
	return '';
    }

    # if there was a head...
    my(@poss) = split '\|\|', $result;
    $poss[0] =~ s/^\s//;
    $poss[$#poss] =~ s/\s$//;

    if ((@poss > 1) && ($msgType =~ /public/)) {
	$result = &getRandom(@poss);
	$result =~ s/^\s*//;
    }

    my $fauthor = &dbGet("factoids", "factoid_key", $message, "created_by");
    ### we need non-evaluating regex like in factoid sar.
    if ($msgType =~ /^private$/) {
	if (defined $fauthor and $fauthor =~ /^\Q$who\E\!/i) {
	    &status("Reply.pl: author requested own factoid in private; literal!");
	    $literal = 1;
	}
    } else {
	my $done = 0;

	# (blah1|blah2)?
	while ($result =~ /\((.*?)\)\?/) {
	    my $str = $1;
	    if (rand() > 0.5) {		# fix.
		&status("Factoid transform: keeping '$str'.");
		$result =~ s/\(\Q$str\E\)\?/$str/;
	    } else {			# remove
		&status("Factoid transform: removing '$str'.");
		$result =~ s/\(\Q$str\E\)\?\s?//;
	    }
	    $done++;
	    last if ($done >= 10);	# just in case.
	}
	$done = 0;

	# EG: (0-32768) => 6325
	### TODO: (1-10,20-30,40) => 24
	while ($result =~ /\((\d+)-(\d+)\)/) {
	    my ($lower,$upper) = ($1,$2);
	    my $new = int(rand $upper-$lower) + $lower;

	    &status("Reply.pl: SARing '$&' to '$new'.");
	    $result =~ s/$&/$new/;
	    $done++;
	    last if ($done >= 10);	# just in case.
	}
	$done = 0;

	# EG: (blah1|blah2|blah3|) => blah1
	while ($result =~ /\((.*?\|.*?)\)/) {
	    my $str = $1;
	    my @rand = split /\|/, $str;
	    my $rand = $rand[rand @rand];

	    &status("Reply.pl: SARing '($str)' to '$rand'.");
	    $result =~ s/\(\Q$str\E\)/$rand/;
	    $done++;
	    last if ($done >= 10);	# just in case.
	}
	&status("Reply.pl: $done SARs done.") if ($done);
    }

    $reply = $result;
    if ($result ne "") {
	### AT LAST, REPEAT PREVENTION CODE REMOVED IN FAVOUR OF GLOBAL
	### FLOOD REPETION AND PROTECTION. -20000124

	# stats code.
	&setFactInfo($lhs,"requested_by", $nuh);
	&setFactInfo($lhs,"requested_time", time());
	### FIXME: old mysql doesn't support
	###	"requested_count=requested_count+1".
	my $count = &getFactInfo($lhs,"requested_count") || 0;
	$count++;
	&setFactInfo($lhs,"requested_count", $count);

	my $real   = 0;
	my $author = &getFactInfo($lhs,"created_by") || '';

	$real++ if ($author =~ /^\Q$who\E\!/);
	$real++ if (&IsFlag("n"));
	$real = 0 if ($msgType =~ /public/);

	### fix up the reply.
	# only remove '<reply>'
	if (!$real and $reply =~ s/^\s*<reply>\s*//i) {
	    # 'are' fix.
	    if ($reply =~ s/^are //i) {
		&DEBUG("Reply.pl: el-cheapo 'are' fix executed.");
		$mhs = "are";
	    }

	} elsif (!$real and $reply =~ s/^\s*<action>\s*(.*)/\cAACTION $1\cA/i) {
	    # only remove '<action>' and make it an action.
	} else {		# not a short reply

	    ### bot->bot reply.
	    if (exists $bots{$nuh} and $rhs !~ /^\s*$/) {
		return "$lhs $mhs $rhs";
	    }

	    ### bot->person reply.
	    # result is random if separated by '||'.
	    # rhs is full factoid with '||'.
	    if ($mhs eq "is") {
		$reply = &getRandom(keys %{$lang{'factoid'}});
		$reply =~ s/##KEY/$lhs/;
		$reply =~ s/##VALUE/$result/;
	    } else {
		$reply = "$lhs $mhs $result";
	    }

	    if ($reply =~ s/^\Q$who\E is/you are/i) {
		# fix the person.
	    } else {
		if ($reply =~ /^you are / or $reply =~ / you are /) {
		    return $noreply if ($addressed);
		}
	    }
	}
    }

    return $reply if ($literal);

    # remove excessive beginning and end whitespaces.
    $reply	=~ s/^\s+|\s+$//g;

    if (length($reply) < 5 or $reply =~ /^\s+$/) {
	&DEBUG("Reply: FIXME: reply => '$reply'.");
	return '';
    }

    return $reply unless ($reply =~ /\$/);

    ###
    ### $ SUBSTITUTION.
    ###
    
    # $date, $time.
    my $date	=  scalar(localtime());
    $date	=~ s/\:\d+(\s+\w+)\s+\d+$/$1/;
    $reply	=~ s/\$date/$date/gi;
    $date	=~ s/\w+\s+\w+\s+\d+\s+//;
    $reply	=~ s/\$time/$date/gi;

    # dollar variables.
    $reply	=~ s/\$nick/$who/g;
    $reply	=~ s/\$who/$who/g;	# backward compat.
    if ($reply =~ /\$(user(name)?|host)/) {
	my ($username, $hostname) = split /\@/, $uh;
	$reply	=~ s/\$user(name)?/$username/g;
	$reply	=~ s/\$host(name)?/$hostname/g;
    }
    $reply	=~ s/\$chan(nel)?/$talkchannel/g;
    if ($msgType =~ /public/) {
	$reply	=~ s/\$lastspeaker/$lastWho{$talkchannel}/g;
    } else {
	$reply	=~ s/\$lastspeaker/$lastWho/g;
    }

    if ($reply =~ /\$rand/) {
	my $rand  = rand();
	my $randp = int($rand*100);
	$reply =~ s/\$randpercentage/$randp/g;
	### TODO: number of digits. 'x.y'
	if ($reply =~ /\$rand(\d+)/) {
	    # will this work as it does in C?
	    $rand = sprintf("%*f", $1, $rand);
	}
	$reply =~ s/\$rand/$rand/g;
    }

    $reply	=~ s/\$factoid/$lhs/g;
    $reply	=~ s/\$ident/$ident/g;

    if ($reply =~ /\$startTime/) {
	my $time = scalar(localtime $^T);
	$reply =~ s/\$startTime/$time/;
    }

    if ($reply =~ /\$uptime/) {
	my $uptime = &Time2String(time() - $^T);
	$reply =~ s/\$uptime/$uptime/;
    }

    if ($reply =~ /\$factoids/) {
	my $count = &countKeys("factoids");
	$reply =~ s/\$factoids/$factoids/;
    }

    if ($reply =~ /\$Fupdate/) {
	my $x = "\002$count{'Update'}\002 ".
		&fixPlural("modification", $count{'Update'});
	$reply =~ s/\$Fupdate/$x/;
    }

    if ($reply =~ /\$Fquestion/) {
	my $x = "\002$count{'Question'}\002 ".
		&fixPlural("question", $count{'Question'});
	$reply =~ s/\$Fquestion/$x/;
    }

    if ($reply =~ /\$Fdunno/) {
	my $x = "\002$count{'Dunno'}\002 ".
		&fixPlural("dunno", $count{'Dunno'});
	$reply =~ s/\$Fdunno/$x/;
    }

    $reply	=~ s/\$memusage/$memusage/;

    $reply;
}

1;
