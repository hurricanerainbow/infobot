#
# Update.pl: Add or modify factoids in the db.
#    Author: Kevin Lenzo
#	     xk <xk@leguin.openprojects.net>
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
    return 'NOREPLY' if (&IsLocked($lhs) == 1);

    # profanity.
    if (&IsParam("profanityCheck") and &hasProfanity($rhs)) {
	&msg($who, "please, watch your language.");
	return 'NOREPLY';
    }

    # teaching.
    if (&IsFlag("t") ne "t") {
	&msg($who, "permission denied.");
	&status("alert: $who wanted to teach me.");
	return 'NOREPLY';
    }

    # nice 'are' hack (or work-around).
    if ($mhs =~ /^are$/i and $rhs !~ /<\S+>/) {
	$mhs = "is";
	$rhs = "<REPLY> are ". $rhs;
    }

    # invalid verb.
    if ($mhs !~ /^is$/i) {
	&ERROR("UNKNOWN verb: $mhs.");
	return;
    }

    # check if the arguments are too long to be stored in our table.
    if (length($lhs) > $param{'maxKeySize'} or 
	length($rhs) > $param{'maxDataSize'})
    {
	&performAddressedReply("that's too long");
	return 'NOREPLY';
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
	    return 'NOREPLY';
	}
    }

    if (my $exists = &getFactoid($lhs)) {	# factoid exists.
	chomp $exists;

	if ($exists eq $rhs) {
	    &performAddressedReply("i already had it that way");
	    return 'NOREPLY';
	}

	if ($also) {			# 'is also'.
	    if ($also_or) {			# 'is also ||'.
		$rhs = $exists.' || '.$rhs;
	    } else {
		if ($rhs =~ /^[A-Z]/) {
		    if ($rhs =~ /\w+\s*$/) {
			&status("auto insert period to factoid.");
			$rhs = $exists.".  ".$rhs;
		    } else {	# '?' or '.' assumed at end.
			&status("orig factoid already had trailing symbol; not adding period.");
			$rhs = $exists."  ".$rhs;
		    }
		} elsif ($exists =~ /\,\s*$/) {
		    $rhs = $exists." ".$rhs;
		} elsif ($rhs =~ /^\./) {
		    $rhs = $exists.$rhs;
		} else {
		    $rhs = $exists.', or '.$rhs;
		}
	    }

	    # max length check again.
	    if (length($rhs) > $param{'maxDataSize'}) {
		&performAddressedReply("that's too long");
		return 'NOREPLY';
	    }

	    &performAddressedReply("okay");

	    $count{'Update'}++;
	    &status("update: <$who> \'$lhs\' =$mhs=> \'$rhs\'; was \'$exists\'");
	    &AddModified($lhs,$nuh);
	    &setFactInfo($lhs, "factoid_value", $rhs);
	} else {				# not "also"
	    if ($correction_plausible) {	# "no, blah is ..."
		my $author = &getFactInfo($lhs, "created_by");

		&DEBUG("Update: check: '$author' == '$who' ?");

		if (IsFlag("m") ne "m" and $author !~ /^\Q$who\E\!/i) {
		    &msg($who, "you can't change that factoid.");
		    return 'NOREPLY';
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
		return 'NOREPLY';
	    }
	}
    } else {			# not exists.
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
