###
### Question.pl: Kevin Lenzo  (c) 1997
###

##  doQuestion --
##	if ($query == query) {
##		return $value;
##	} else {
##		return NULL;
##	}
##
##

if (&IsParam("useStrict")) { use strict; }

use vars qw($query $reply $finalQMark $nuh $result $talkok $who $nuh);
use vars qw(%bots %forked);

sub doQuestion {
    # my doesn't allow variables to be inherinted, local does.
    # following is used in math()...
    local($query)	= @_;
    local($reply)	= "";
    local $finalQMark	= $query =~ s/\?+\s*$//;
    $finalQMark		+= $query =~ s/\?\s*$//;
    $query		=~ s/^\s+|\s+$//g;

    if (!defined $query or $query =~ /^\s*$/) {
	return '';
    }

    my $questionWord	= "";

    if (!$addressed) {
	return '' unless ($finalQMark);
	return '' if (&IsParam("minVolunteerLength") == 0);
	return '' if (length $query < $param{'minVolunteerLength'});
    } else {
	### TODO: this should be caught in Process.pl?
	return '' unless ($talkok);
    }

    # dangerous; common preambles should be stripped before here
    if ($query =~ /^forget /i or $query =~ /^no, /) {
	return if (exists $bots{$nuh});
    }

    if ($query =~ s/^literal\s+//i) {
	&status("literal ask of '$query'.");
	$literal = 1;
    }

    # convert to canonical reference form
    my $x;
    my @query;

    push(@query, $query);	# 1: push original.

    # valid factoid.
    if ($query =~ s/[!.]$//) {
	push(@query,$query);
    }

    $x = &normquery($query);
    push(@query, $x) if ($x ne $query);
    $query = $x;

    $x = &switchPerson($query);
    push(@query, $x) if ($x ne $query);
    $query = $x;

    $query =~ s/\s+at\s*(\?*)$/$1/;	# where is x at?
    $query =~ s/^explain\s*(\?*)/$1/i;	# explain x
    $query = " $query ";		# side whitespaces.

    my $qregex = join '|', keys %{ $lang{'qWord'} };

    # what's whats => what is; who'?s => who is, etc
    $query =~ s/ ($qregex)\'?s / $1 is /i;
    if ($query =~ s/\s+($qregex)\s+//i) { # check for question word
	$questionWord = lc($1);
    }

    if ($questionWord eq "" and $finalQMark and $addressed) {
	$questionWord = "where";
    }

    if (&IsChanConf("factoidArguments")) {
	$result = &factoidArgs($query[0]);

	return $result if (defined $result);
    }

    my @link;
    for (my$i=0; $i<scalar @query; $i++) {
	$query	= $query[$i];
	$result = &getReply($query);
	next if (!defined $result or $result eq "");

	# 'see also' factoid redirection support.

	while ($result =~ /^see( also)? (.*?)\.?$/) {
	    my $link	= $2;

	    if (grep /^$link$/i, @link) {
		&status("recursive link found; bailing out.");
		last;
	    }

	    if (scalar @link >= 5) {
		&status("recursive link limit reached.");
		last;
	    }

	    push(@link, $link);
	    my $newr = &getReply($link);
	    last if (!defined $newr or $newr eq "");
	    $result  = $newr;
	}

	if (@link) {
	    &status("'$query' linked to: ".join(" => ", @link) );
	}

	if ($i != 0) {
	    &VERB("Question.pl: '$query[0]' did not exist; '$query[$i]' ($i) did",2);
	}

	return $result;
    }

    ### TODO: Use &Forker(); move function to Freshmeat.pl.
    if (&IsChanConf("freshmeatForFactoid")) {
	&loadMyModule($myModules{'freshmeat'});
	$result = &Freshmeat::showPackage($query);
	return $result if (defined $result);
    }

    ### TODO: Use &Forker(); move function to Debian.pl
    if (&IsChanConf("debianForFactoid")) {
	&loadMyModule($myModules{'debian'});
	$result = &Debian::DebianFind($query);	# ???
	### TODO: debian module should tell, through shm, that it went
	###	  ok or not.
###	return $result if (defined $result);
    }

    if ($questionWord ne "" or $finalQMark) {
	# if it has not been explicitly marked as a question
	if ($addressed and $reply eq "") {
	    &status("notfound: <$who> ".join(' :: ', @query))
						if ($finalQMark);

	    return '' unless (&IsParam("friendlyBots"));

	    foreach (split /\s+/, $param{'friendlyBots'}) {
		&msg($_, ":INFOBOT:QUERY <$who> $query");
	    }
	}
    }

    return $reply;
}

sub factoidArgs {
    my($str)	= @_;
    my $result;

    # to make it eleeter, split each arg and use "blah OR blah or BLAH"
    # which will make it less than linear => quicker!
    # todo: cache this, update cache when altered. !!! !!! !!!
#    my $t = &timeget();
    my @list = &searchTable("factoids", "factoid_key", "factoid_key", "^CMD: ");
#    my $delta_time = &timedelta($t);
#    &DEBUG("factArgs: delta_time = $delta_time s");
#    &DEBUG("factArgs: list => ".scalar(@list) );

    # from a design perspective, it's better to have the regex in
    # the factoid key to reduce repetitive processing.

    # it does not matter if it's not alphabetically sorted.
    foreach (sort { length($b) <=> length($a) } @list) {
	next if (/#DEL#/);	# deleted.

	s/^CMD: //i;
#	&DEBUG("factarg: ''$str' =~ /^$_\$/'");
	my $arg = $_;

	# todo: <greycat> ~punish apt for (Eating) (Parentheses)
	# how the hell do I fix the above? -dms.

	# eval (evil!) code. cleaned up courtesy of lear.
	my @vals;
	eval {
	    @vals = ($str =~ /^$arg$/i);
	};

	if ($@) {
	    &WARN("factargs: regex failed! '$str' =~ /^$_\$/");
	    next;
	}

	next unless (@vals);

	if (defined $result) {
	    &WARN("factargs: '$_' matches aswell.");
	    next;
	}

#	&DEBUG("vals => @vals");

	&status("Question: factoid Arguments for '$str'");
	# todo: use getReply() - need to modify it :(
	my $i	= 0;
	my $q	= "CMD: $_";
	my $r	= &getFactoid($q);
	if (!defined $r) {
	    &DEBUG("question: !result... should this happen?");
	    return;
	}

	# update stats.
	my $count = &getFactInfo($q, "requested_count") || 0;
	$count++;
	&setFactInfo($q, "requested_by", $nuh);
	&setFactInfo($q, "requested_time", time());
	&setFactInfo($q, "requested_count", $count);
	# end of update stats.

	$result	= $r;
	$result	=~ s/^\((.*?)\): //;

	foreach ( split(',', $1) ) {
	    my $val = $vals[$i];
#	    &DEBUG("val => $val");

	    if (!defined $val) {
		&status("factArgs: vals[$i] == undef; not SARing '$_' for '$str'");
		next;
	    }

	    my $done = 0;
	    my $old = $result;
	    while (1) {
#		&DEBUG("Q: result => $result (1before)");
		$result = &substVars($result);
#		&DEBUG("Q: result => $result (1after)");

		last if ($old eq $result);
		$old = $result;
		$done++;
	    }

	    # hack.
	    $vals[$i] =~ s/^me$/$who/gi;

	    if (!$done) {
		&status("factArgs: SARing '$_' to '$vals[$i]'.");
		$result =~ s/\Q$_\E/$vals[$i]/g;
	    }
	    $i++;
	}

	# nasty hack to get partial &getReply() functionality.
	$result =~ s/^\s*<action>\s*(.*)/\cAACTION $1\cA/i;
	$result =~ s/^\s*<reply>\s*//i;
	$result = &SARit($result);

# well... lets go through all of them. not advisable if we have like
# 1000 commands, heh.
#	return $result;
	$cmdstats{'Factoid Commands'}++;
    }

    return $result;
}

1;
