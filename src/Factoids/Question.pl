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

    if (!defined $query or $query =~ /^\s*$/) {
	&FIXME("doQ: query == NULL");
	return '';
    }

    my $origQuery = $query;

    my $questionWord	= "";

    if (!$addressed) {
	return '' unless ($finalQMark);

	if (&IsParam("minVolunteerLength") == 0 or
		length($query) < $param{'minVolunteerLength'})
	{
	    return '';
	}
    } else {
	### TODO: this should be caught in Process.pl?
	return '' unless ($talkok);
    }

    # dangerous; common preambles should be stripped before here
    if ($query =~ /^forget /i or $query =~ /^no, /) {
	return $noreply if (exists $bots{$nuh});
    }

    # convert to canonical reference form
    $query = &normquery($query);
    $query = &switchPerson($query);

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

    $query =~ s/^\s+|\s+$//g;

    # valid factoid.
    if (defined( $result = &getReply($query) )) {
	# 'see also' factoid redirection support.
	if ($result =~ /^see( also)? (.*?)\.?$/) {
	    my $newr = &getReply($2);
	    $result  = $newr	if ($newr ne "");
	}

	return $result if ($result ne "");

	### TODO: Use &Forker(); move function to Freshmeat.pl.
	if (&IsParam("freshmeatForFactoid")) {
	    &loadMyModule($myModules{'freshmeat'});
	    $result = &Freshmeat::showPackage($query);
	    return $result unless ($result eq $noreply);
	}

	&DEBUG("Question: hrm... result => '$result'.");
    }

    if ($questionWord ne "" or $finalQMark) {
	# if it has not been explicitly marked as a question
	if ($addressed and $reply eq "") {
	    if ($origQuery eq $query) {
		&status("notfound: <$who> $origQuery");
	    } else {
		&status("notfound: <$who> $origQuery :: $query");
	    }

	    return '' unless (&IsParam("friendlyBots"));

	    foreach (split /\s+/, $param{'friendlyBots'}) {
		&msg($_, ":INFOBOT:QUERY <$who> $query");
	    }
	}
    }

    $reply;
}

1;
