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
    local($query) = @_;
    local($reply) = "";
    local $finalQMark = $query =~ s/\?+\s*$//;
    $finalQMark += $query =~ s/\?\s*$//;
    $query =~ s/^\s+|\s+$//g;

    if (!defined $query or $query =~ /^\s*$/) {
	&FIXME("doQ: query == NULL");
	return '';
    }

    my $questionWord	= "";

    if (!$addressed) {
	return '' unless ($finalQMark);
	return '' if (&IsParam("minVolunteerLength") == 0);
	return '' if (length($query) < $param{'minVolunteerLength'});
    } else {
	### TODO: this should be caught in Process.pl?
	return '' unless ($talkok);
    }

    # dangerous; common preambles should be stripped before here
    if ($query =~ /^forget /i or $query =~ /^no, /) {
	return if (exists $bots{$nuh});
    }

    # convert to canonical reference form
    my $x;
    my @query;

    push(@query, $query);	# 1: push original.

    $x = &normquery($query);
    push(@query, $x) if ($x ne $query);
    $query = $x;

    $x = &switchPerson($query);
    push(@query, $x) if ($x ne $query);
    $query = $x;

    $query =~ s/\s+at\s*(\?*)$/$1/;	# where is x at?
    $query =~ s/^explain\s*(\?*)/$1/i;	# explain x
    $query = " $query ";		# side whitespaces.

    my $qregex = join '|', keys %{$lang{'qWord'}};

    # what's whats => what is; who'?s => who is, etc
    $query =~ s/ ($qregex)\'?s / $1 is /i;
    if ($query =~ s/\s+($qregex)\s+//i) { # check for question word
	$questionWord = lc($1);
    }

    if ($questionWord eq "" and $finalQMark and $addressed) {
	$questionWord = "where";
    }

    # valid factoid.
    if ($query =~ s/[\!\.]$//) {
	push(@query,$query);
    }

    for (my$i=0; $i<scalar(@query); $i++) {
	$query	= $query[$i];
	$result = &getReply($query);
	next if (!defined $result or $result eq "");

	# 'see also' factoid redirection support.
	if ($result =~ /^see( also)? (.*?)\.?$/) {
	    my $newr = &getReply($2);
	    $result  = $newr	if ($newr ne "");
	}

	if ($i != 0) {
	    &DEBUG("Question: guessed factoid correctly ($i) => '$query'.");
	}

	return $result;
    }

    ### TODO: Use &Forker(); move function to Freshmeat.pl.
    if (&IsParam("freshmeatForFactoid")) {
	&loadMyModule($myModules{'freshmeat'});
	$result = &Freshmeat::showPackage($query);
	return $result if (defined $result);
    }

    ### TODO: Use &Forker(); move function to Debian.pl
    if (&IsParam("debianForFactoid")) {
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

    $reply;
}

1;
