#
# Update.pl: Add or modify factoids in the db.
#    Author: Kevin Lenzo
#	     dms
#   Version: 19991209
#   Created: 1997
#

if (&IsParam("useStrict")) { use strict; }

sub update {
    my($lhs, $mhs, $rhs) = @_;

    $lhs =~ s/^i (heard|think) //i;
    $lhs =~ s/^some(one|1|body) said //i;
    $lhs =~ s/\s+/ /g;

    # locked.
    return $noreply if (&IsLocked($lhs) == 1);

    # profanity.
    if (&IsParam("profanityCheck") and &hasProfanity($rhs)) {
	&msg($who, "please, watch your language.");
	return $noreply;
    }

    # teaching.
    if (&IsFlag("t") ne "t") {
	&msg($who, "permission denied.");
	&status("alert: $who wanted to teach me.");
	return $noreply;
    }

    # invalid verb.
    if ($mhs !~ /^(is|are)$/i) {
	&ERROR("UNKNOWN verb: $mhs.");
	return;
    }

    # check if the arguments are too long to be stored in our table.
    if (length($lhs) > $param{'maxKeySize'} or 
	length($rhs) > $param{'maxDataSize'})
    {
	&performAddressedReply("that's too long");
	return $noreply;
    }

    #
    # lets do it...
    #

    my $also    = ($rhs =~ s/^also //i);
    my $also_or = ($also and $rhs =~ s/\s+(or|\|\|)\s+//);

    if (&IsParam("freshmeatForFactoid")) {
	if (&dbGet("freshmeat", "name", $lhs, "name")) {
	    &msg($who, "permission denied. (freshmeat)");
	    &status("alert: $who wanted to teach me something that freshmeat already has info on.");
	    return $noreply;
	}
    }

    if (my $exists = &getFactoid($lhs)) {	# factoid exists.
	if ($exists eq $rhs) {
	    &performAddressedReply("i already had it that way");
	    return $noreply;
	}

	if ($also) {			# 'is also'.
	    if ($also_or) {			# 'is also ||'.
		$rhs = $exists.' || '.$rhs;
	    } else {
#		if ($exists =~ s/\,\s*$/,  /) {
		if ($exists =~ /\,\s*$/) {
		    &DEBUG("current has trailing comma, just append as is");
		    # $rhs =~ s/^\s+//;
		    # $rhs = $exists." ".$rhs;	# keep comma.
		}

		if ($exists =~ /\.\s*$/) {
		    &DEBUG("current has trailing period, just append as is with 2 WS");
		    # $rhs =~ s/^\s+//;
		    # use ucfirst();?
		    # $rhs = $exists."  ".$rhs;	# keep comma.
		}

		if ($rhs =~ /^[A-Z]/) {
		    if ($rhs =~ /\w+\s*$/) {
			&status("auto insert period to factoid.");
			$rhs = $exists.".  ".$rhs;
		    } else {	# '?' or '.' assumed at end.
			&status("orig factoid already had trailing symbol; not adding period.");
			$rhs = $exists."  ".$rhs;
		    }
		} elsif ($exists =~ /[\,\.\-]\s*$/) {
		    &VERB("U: current has trailing symbols; inserting whitespace + new.",2);
		    $rhs = $exists." ".$rhs;
		} elsif ($rhs =~ /^\./) {
		    &VERB("U: new text has ^.; appending directly",2);
		    $rhs = $exists.$rhs;
		} else {
		    $rhs = $exists.', or '.$rhs;
		}
	    }

	    # max length check again.
	    if (length($rhs) > $param{'maxDataSize'}) {
		&performAddressedReply("that's too long");
		return $noreply;
	    }

	    &performAddressedReply("okay");

	    $count{'Update'}++;
	    &status("update: <$who> \'$lhs\' =$mhs=> \'$rhs\'; was \'$exists\'");
	    &AddModified($lhs,$nuh);
	    &setFactInfo($lhs, "factoid_value", $rhs);
	} else {				# not "also"
	    if ($correction_plausible) {	# "no, blah is ..."
		my $author = &getFactInfo($lhs, "created_by") || "";

		if (IsFlag("m") ne "m" and $author !~ /^\Q$who\E\!/i) {
		    &msg($who, "you can't change that factoid.");
		    return $noreply;
		}

		&performAddressedReply("okay");

		$count{'Update'}++;
		&status("update: <$who> \'$lhs\' =$mhs=> \'$rhs\'; was \'$exists\'");

		&delFactoid($lhs);
		&setFactInfo($lhs,"created_by", $nuh);
		&setFactInfo($lhs,"created_time", time());
		&setFactInfo($lhs,"factoid_value", $rhs);
	    } else {			 # "blah is ..."
		if ($addressed) {
		    &performStrictReply("...but \002$lhs\002 is already something else...");
		    &status("FAILED update: <$who> \'$lhs\' =$mhs=> \'$rhs\'");
		}
		return $noreply;
	    }
	}
    } else {			# not exists.

	# nice 'are' hack (or work-around).
	if ($mhs =~ /^are$/i and $rhs !~ /<\S+>/) {
	    &DEBUG("Update: 'are' hack detected.");
	    $mhs = "is";
	    $rhs = "<REPLY> are ". $rhs;
	}

	&status("enter: <$who> \'$lhs\' =$mhs=> \'$rhs\'");
	$count{'Update'}++;

	&performAddressedReply("okay");

	&setFactInfo($lhs,"created_by", $nuh);
	&setFactInfo($lhs,"created_time", time());
	&setFactInfo($lhs,"factoid_value", $rhs);
    }

    return "$lhs $mhs $rhs";
}

1;
