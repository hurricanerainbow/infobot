#
# Topic.pl: Advanced topic management (maxtopiclen>=512)
#   Author: dms
#  Version: v0.8 (19990919).
#  Created: 19990720
#

use strict;
use vars qw(%topiccmp);
no strict "refs";		### FIXME!!!

###############################
##### INTERNAL FUNCTIONS
###############################

###
# Usage: &topicDecipher(chan);
sub topicDecipher {
  my $chan	= shift;
  my @results;

  if (!exists $topic{$chan}{'Current'}) {
    return;
  }

  foreach (split /\|\|/, $topic{$chan}{'Current'}) {
    s/^\s+//;
    s/\s+$//;

    # very nice fix to solve the null subtopic problem.
    ### if nick contains a space, treat topic as ownerless.
    if (/^\(.*?\)$/) {
	next unless ($1 =~ /\s/);
    }

    my $subtopic	= $_;
    my $owner		= "Unknown";
    if (/(.*)\s+\((.*?)\)$/) {
	$subtopic	= $1;
	$owner		= $2;
    }

    if (grep /^\Q$subtopic\E\|\|\Q$owner\E$/, @results) {
	&status("Topic: we have found a dupe in the topic, not adding.");
	next;
    }

    push(@results, "$subtopic||$owner");
  }

  return @results;
}

###
# Usage: &topicCipher(@topics);
sub topicCipher {
  if (!@_) {
    &DEBUG("topicCipher: topic is NULL.");
    return;
  }

  my $result;
  foreach (@_) {
    my ($subtopic, $setby) = split /\|\|/;

    $result .= " || $subtopic";
    next if ($setby eq "" or $setby =~ /unknown/i);

    $result .= " (" . $setby . ")";
  }

  return substr($result, 4);
}

###
# Usage: &topicNew($chan, $topic, $updateMsg, $topicUpdate);
sub topicNew {
  my ($chan, $topic, $updateMsg, $topicUpdate) = @_;
  my $maxlen = 470;

  if ($channels{$chan}{t} and !$channels{$chan}{o}{$ident}) {
    &msg($who, "error: cannot change topic without ops. (channel is +t) :(");
    return 0;
  }

  if (defined $topiccmp{$chan} and $topiccmp{$chan} eq $topic) {
    &msg($who, "warning: action had no effect on topic; no change required.");
    return 0;
  }

  # bail out if the new topic is too long.
  my $newlen = length($chan.$topic);
  if ($newlen > $maxlen) {
    &msg($who, "new topic will be too long. ($newlen > $maxlen)");
    return 0;
  }

  $topic{$chan}{'Current'} = $topic;

  # notification that the topic was altered.
  if (!$topicUpdate) {		# for cached changes with '-'.
    &performReply("okay");
    return 1;
  }

  if ($updateMsg ne "") {
    &msg($who, $updateMsg);
  }

  $topic{$chan}{'Last'} = $topic;
  $topic{$chan}{'Who'}  = $orig{who}."!".$uh;
  $topic{$chan}{'Time'} = time();
  rawout("TOPIC $chan :$topic");
  &topicAddHistory($chan,$topic);
  return 1;
}

###
# Usage: &topicAddHistory($chan,$topic);
sub topicAddHistory {
  my ($chan, $topic)	= @_;
  my $dupe		= 0;

  return 1 if ($topic eq "");			# required fix.

  foreach (@{ $topic{$chan}{'History'} }) {
    next	if ($_ ne "" and $_ ne $topic);
    # checking length is required.

    $dupe++;
    last;
  }

  return 1	if $dupe;

  my @topics = @{ $topic{$chan}{'History'} };
  unshift(@topics, $topic);
  pop(@topics) while (scalar @topics > 6);
  $topic{$chan}{'History'} = \@topics;

  return $dupe;
}

###############################
##### HELPER FUNCTIONS
###############################

### TODO.
# sub topicNew {
# sub topicDelete {
# sub topicList {
# sub topicModify {
# sub topicMove {
# sub topicShuffle {
# sub topicHistory {
# sub topicRestore {
# sub topicRehash {
# sub topicHelp {

###############################
##### MAIN
###############################

###
# Usage: &Topic($cmd, $args);
sub Topic {
  my ($chan, $cmd, $args) = @_;
  my $topicUpdate = 1;

  if ($cmd =~ /^-(\S+)/) {
    $topicUpdate = 0;
    $cmd = $1;
  }

  if ($cmd =~ /^(add)$/i) {
    ### CMD: ADD:
    if ($args eq "") {
	&help("topic add");
	return $noreply;
    }

    # heh, joeyh. 19990819. -xk
    if ($who =~ /\|\|/) {
	&msg($who, "error: you have an invalid nick, loser!");
	return $noreply;
    }

    my @prev = &topicDecipher($chan);
    my $new  = "$args ($orig{who})";
    $topic{$chan}{'What'} = "Added '$args'.";
    if (scalar @prev) {
      $new = &topicCipher(@prev, sprintf("%s||%s", $args, $who));
    }
    &topicNew($chan, $new, "", $topicUpdate);

  } elsif ($cmd =~ /^(del|delete|rm|remove|kill|purge)$/i) {
    ### CMD: DEL:
    my @subtopics	= &topicDecipher($chan);
    my $topiccount	= scalar @subtopics;

    if ($topiccount == 0) {
	&msg($who, "No topic set.");
	return $noreply;
    }

    if ($args eq "") {
	&help("topic del");
	return $noreply;
    }

    $args =  ",".$args.",";
    $args =~ s/\s+//g;
    $args =~ s/(first|1st)/1/i;
    $args =~ s/last/$topiccount/i;
    $args =~ s/,-(\d+)/,1-$1/;
    $args =~ s/(\d+)-,/,$1-$topiccount/;

    if ($args !~ /[\,\-\d]/) {
	&msg($who, "error: Invalid argument ($args).");
	return $noreply;
    }

    foreach (split ",", $args) {
	next if ($_ eq "");
	my @delete;

	# change to hash list instead of array?
	if (/^(\d+)-(\d+)$/) {
	    my ($from,$to) = ($1,$2);
	    ($from,$to) = ($2,$1)	if ($from > $to);

	    push(@delete, $1..$2);
	} elsif (/^(\d+)$/) {
	    push(@delete, $1);
	} else {
	    &msg($who, "error: Invalid sub-argument ($_).");
	    return $noreply;
	}

	$topic{$chan}{'What'} = "Deleted ".join("/",@delete);

	foreach (@delete) {
	  if ($_ > $topiccount || $_ < 1) {
	    &msg($who, "error: argument out of range. (max: $topiccount)");
	    return $noreply;
	  }
	  # skip if already deleted.
	  # only checked if x-y range is given.
	  next unless (defined($subtopics[$_-1]));

	  my ($subtopic,$whoby) = split('\|\|', $subtopics[$_-1]);
	  $whoby		= "unknown"	if ($whoby eq "");
	  &msg($who, "Deleting topic: $subtopic ($whoby)");
	  undef $subtopics[$_-1];
	}
    }

    my @newtopics;
    foreach (@subtopics) {
	next unless (defined $_);
	push(@newtopics, $_);
    }

    &topicNew($chan, &topicCipher(@newtopics), "", $topicUpdate);

  } elsif ($cmd =~ /^list$/i) {
    ### CMD: LIST:
    my @topics	= &topicDecipher($chan);
    if (!scalar @topics) {
	&msg($who, "No topics for \002$chan\002.");
	return $noreply;
    }

    &msg($who, "Topics for \002$chan\002:");
    &msg($who, "No  \002[\002  Set by  \002]\002 Topic");

    my $i = 1;
    foreach (@topics) {
	my ($subtopic, $setby) = split /\|\|/;

	&msg($who, sprintf(" %d. \002[\002%-10s\002]\002 %s",
				$i, $setby, $subtopic));
	$i++;
    }
    &msg($who, "End of Topics.");

  } elsif ($cmd =~ /^(mod|modify|change|alter)$/i) {
    ### CMD: MOD:

    if ($args eq "") {
	&help("topic mod");
	return $noreply;
    }

    # a warning message instead of halting. we kind of trust the user now.
    if ($args =~ /\|\|/) {
	&msg($who, "warning: adding double pipes manually == evil. be warned.");
    }

    $topic{$chan}{'What'} = "SAR $args";

    # SAR patch. mu++
    if ($args =~ m|^\s*s([/,#])(.+?)\1(.*?)\1([a-z]*);?\s*$|) {
	my ($delim, $op, $np, $flags) = ($1,quotemeta $2,$3,$4);

	if ($flags !~ /^(g)?$/) {
	  &msg($who, "error: Invalid flags to regex.");
	  return $noreply;
	}

	my $topic = $topic{$chan}{'Current'};

	if (($flags eq "g" and $topic =~ s/$op/$np/g) ||
	    ($flags eq ""  and $topic =~ s/$op/$np/)) {

	  $_ = "Modifying topic with sar s/$op/$np/.";
	  &topicNew($chan, $topic, $_, $topicUpdate);
	} else {
	  &msg($who, "warning: regex not found in topic.");
	}
	return $noreply;
    }

    &msg($who, "error: Invalid regex. Try s/1/2/, s#3#4#...");

  } elsif ($cmd =~ /^(mv|move)$/i) {
    ### CMD: MV:

    if ($args eq "") {
	&help("topic mv");
	return $noreply;
    }

    if ($args =~ /^(first|last|\d+)\s+(before|after|swap)\s+(first|last|\d+)$/i) {
	my ($from, $action, $to) = ($1,$2,$3);
	my @subtopics  = &topicDecipher($chan);
	my @newtopics;
	my $topiccount = scalar @subtopics;

	if ($topiccount == 1) {
	  &msg($who, "error: impossible to move the only subtopic, dumbass.");
	  return $noreply;
	}

	# Is there an easier way to do this?
	$from =~ s/first/1/i;
	$to   =~ s/first/1/i;
	$from =~ s/last/$topiccount/i;
	$to   =~ s/last/$topiccount/i;

	if ($from > $topiccount || $to > $topiccount || $from < 1 || $to < 1) {
	  &msg($who, "error: <from> or <to> is out of range.");
	  return $noreply;
	}

	if ($from == $to) {
	  &msg($who, "error: <from> and <to> are the same.");
	  return $noreply;
	}

	$topic{$chan}{'What'} = "Move $from to $to";

	if ($action =~ /^(swap)$/i) {
	  my $tmp			= $subtopics[$to   - 1];
	  $subtopics[$to   - 1]		= $subtopics[$from - 1];
	  $subtopics[$from - 1]		= $tmp;

	  $_ = "Swapped #\002$from\002 with #\002$to\002.";
	  &topicNew($chan, &topicCipher(@subtopics), $_, $topicUpdate);
	  return $noreply;
	}

	# action != swap:
	# Is there a better way to do this? guess not.
	my $i		= 1;
	my $subtopic	= $subtopics[$from - 1];
	foreach (@subtopics) {
	  my $j = $i*2 - 1;
	  $newtopics[$j] = $_	if ($i != $from);
	  $i++;
	}

	if ($action =~ /^(before|b4)$/i) {
	    $newtopics[$to*2-2] = $subtopic;
	} else {
	    # action =~ /after/.
	    $newtopics[$to*2] = $subtopic;
	}

	undef @subtopics;			# lets reuse this array.
	foreach (@newtopics) {
	  next if ($_ eq "");
	  push(@subtopics, $_);
	}

	$_ = "Moved #\002$from\002 $action #\002$to\002.";
	&topicNew($chan, &topicCipher(@subtopics), $_, $topicUpdate);

	return $noreply;
    }

    &msg($who, "Invalid arguments.");

  } elsif ($cmd =~ /^shuffle$/i) {
    ### CMD: SHUFFLE:
    my @subtopics  = &topicDecipher($chan);
    my @newtopics;

    $topic{$chan}{'What'} = "shuffled";

    foreach (&makeRandom(scalar @subtopics)) {
	push(@newtopics, $subtopics[$_]);
    }

    $_ = "Shuffling the bag of lollies.";
    &topicNew($chan, &topicCipher(@newtopics), $_, $topicUpdate);

  } elsif ($cmd =~ /^(history)$/i) {
    ### CMD: HISTORY:
    if (!scalar @{$topic{$chan}{'History'}}) {
	&msg($who, "Sorry, no topics in history list.");
	return $noreply;
    }

    &msg($who, "History of topics on \002$chan\002:");
    for (1 .. scalar @{$topic{$chan}{'History'}}) {
	my $topic = ${$topic{$chan}{'History'}}[$_-1];
	&msg($who, "  #\002$_\002: $topic");

	# To prevent excess floods.
	sleep 1 if (length($topic) > 160);
    }
    &msg($who, "End of list.");

  } elsif ($cmd =~ /^restore$/i) {
    ### CMD: RESTORE:
    if ($args eq "") {
	&help("topic restore");
	return $noreply;
    }

    $topic{$chan}{'What'} = "Restore topic $args";

    # following needs to be verified.
    if ($args =~ /^last$/i) {
	if (${$topic{$chan}{'History'}}[0] eq $topic{$chan}{'Current'}) {
	    &msg($who,"error: cannot restore last topic because it's mine.");
	    return $noreply;
	}
	$args = 1;
    }

    if ($args =~ /\d+/) {
	if ($args > $#{$topic{$chan}{'History'}} || $args < 1) {
	    &msg($who, "error: argument is out of range.");
	    return $noreply;
	}

	$_ = "Changing topic according to request.";
	&topicNew($chan, ${$topic{$chan}{'History'}}[$args-1], $_, $topicUpdate);

	return $noreply;
    }

    &msg($who, "error: argument is not positive integer.");

  } elsif ($cmd =~ /^rehash$/i) {
    ### CMD: REHASH.
    $_ = "Rehashing topic...";
    $topic{$chan}{'What'} = "Rehash";
    &topicNew($chan, $topic{$chan}{'Current'}, $_, 1);

  } elsif ($cmd =~ /^info$/i) {
    ### CMD: INFO.
    my $reply = "no topic info.";
    if (exists $topic{$chan}{'Who'} and exists $topic{$chan}{'Time'}) {
	$reply = "topic on \002$chan\002 was last set by ".
		$topic{$chan}{'Who'}. ".  This was done ".
		&Time2String(time() - $topic{$chan}{'Time'}) ." ago.";
	my $change = $topic{$chan}{'What'};
	$reply .= "Change => $change" if (defined $change);
    }

    &performStrictReply($reply);
  } else {
    ### CMD: HELP:
    if ($cmd ne "" and $cmd !~ /^help/i) {
	&msg($who, "Invalid command [$cmd].");
	&msg($who, "Try 'help topic'.");
	return $noreply;
    }

    &help("topic");
  }

  return $noreply;
}

1;
