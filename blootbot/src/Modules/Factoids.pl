#
#  Factoids.pl: Helpers for generating factoids statistics.
#       Author: dms
#      Version: v0.1 (20000514)
#     Splitted: SQLExtras.pl
#

if (&IsParam("useStrict")) { use strict; }

###
# Usage: &CmdFactInfo($faqtoid, $query);
sub CmdFactInfo {
    my ($faqtoid, $query) = (lc $_[0], $_[1]);
    my @array;
    my $string = "";

    if ($faqtoid eq "") {
	&help("factinfo");
	return;
    }

    my %factinfo = &dbGetColNiceHash("factoids", "*", "factoid_key=".&dbQuote($faqtoid));

    # factoid does not exist.
    if (scalar (keys %factinfo) <= 1) {
	&performReply("there's no such factoid as \002$faqtoid\002");
	return;
    }

    # fix for problem observed by asuffield.
    # why did it happen though?
    if (!$factinfo{'factoid_value'}) {
	&performReply("there's no such factoid as \002$faqtoid\002; deleted because we don't have factoid_value!");
	foreach (keys %factinfo) {
	    &DEBUG("factinfo{$_} => '$factinfo{$_}'.");
	}
###	&delFactoid($faqtoid);
	return;
    }

    # created:
    if ($factinfo{'created_by'}) {

	$factinfo{'created_by'} =~ s/\!/ </;
	$factinfo{'created_by'} .= ">";
	$string  = "created by $factinfo{'created_by'}";

	my $time = $factinfo{'created_time'};
	if ($time) {
	    if (time() - $time > 60*60*24*7) {
		my $days = int( (time() - $time)/60/60/24 );
		$string .= " at \037". scalar(localtime $time). "\037" .
				" ($days days)";
	    } else {
		$string .= " ".&Time2String(time() - $time)." ago";
	    }
	}

	push(@array,$string);
    }

    # modified:
#    if ($factinfo{'modified_by'}) {
#	$string	= "last modified";
#
#	my $time = $factinfo{'modified_time'};
#	if ($time) {
#	    if (time() - $time > 60*60*24*7) {
#		$string .= " at \037". scalar(localtime $time). "\037";
#	    } else {
#		$string .= " ".&Time2String(time() - $time)." ago";
#	    }
#	}
#
#	my @x;
#	foreach (split ",", $factinfo{'modified_by'}) {
#	    /\!/;
#	    push(@x, $`);
#	}
#	$string .= "by ".&IJoin(@x);
#
#	$i++;
#	push(@array,$string);
#    }

    # requested:
    if ($factinfo{'requested_by'}) {
	my $requested_count = $factinfo{'requested_count'};

	if ($requested_count) {
	    $string  = "it has been requested ";
	    if ($requested_count == 1) {
		$string .= "\002once\002";
	    } else {
		$string .= "\002". $requested_count. "\002 ".
			&fixPlural("time", $requested_count);
	    }
	}

	$string .= ", " if ($string ne "");

	my $requested_by = $factinfo{'requested_by'};
	$requested_by =~ /\!/;
	$string .= "last by $`";

	my $requested_time = $factinfo{'requested_time'};
	if ($requested_time) {
	    if (time() - $requested_time > 60*60*24*7) {
		$string .= " at \037". scalar(localtime $requested_time). "\037";
	    } else {
		$string .= ", ".&Time2String(time() - $requested_time)." ago";
	    }
	}

	push(@array,$string);
    }

    # locked:
    if ($factinfo{'locked_by'}) {
	$factinfo{'locked_by'} =~ /\!/;
	$string = "it has been locked by $`";

	push(@array, $string);
    }

    # factoid was inserted not through the bot.
    if (!scalar @array) {
	&performReply("no extra info on \002$faqtoid\002");
	return;
    }

    &performStrictReply("$factinfo{'factoid_key'} -- ". join("; ", @array) .".");
    return;
}

sub CmdFactStats {
    my ($type) = @_;

    if ($type =~ /^author$/i) {
	my %hash = &dbGetCol("factoids", "factoid_key,created_by", "created_by IS NOT NULL");
	my %author;

	foreach (keys %hash) {
	    my $thisnuh = $hash{$_};

	    $thisnuh =~ /^(\S+)!\S+@\S+$/;
	    $author{lc $1}++;
	}

	if (!scalar keys %author) {
	    return 'sorry, no factoids with created_by field.';
	}

	# work-around.
	my %count;
	foreach (keys %author) {
	    $count{ $author{$_} }{$_} = 1;
	}
	undef %author;

	my $count;
	my @list;
	foreach $count (sort { $b <=> $a } keys %count) {
	    my $author = join(", ", sort keys %{ $count{$count} });
	    push(@list, "$count by $author");
	}

	my $prefix = "factoid statistics by author: ";
	return &formListReply(0, $prefix, @list);

    } elsif ($type =~ /^vandalism$/i) {
        &status("factstats(vandalism): starting...");
	my $start_time	= &timeget();
	my %data	= &dbGetCol("factoids", "factoid_key,factoid_value", "factoid_value IS NOT NULL");
	my @list;

	my $delta_time	= &timedelta($start_time);
        &status(sprintf("factstats(vandalismbroken): %.02f sec to retreive all factoids.", $delta_time)) if ($delta_time > 0);
	$start_time	= &timeget();

	# parse the factoids.
	foreach (keys %data) {
	    if (&validFactoid($_, $data{$_}) == 0) {
		s/([\,\;]+)/\037$1\037/g;	# highlight chars.
		push(@list, $_);		# push it.
	    }
	}

	$delta_time	= &timedelta($start_time);
        &status(sprintf("factstats(vandalism): %.02f sec to complete.", $delta_time)) if ($delta_time > 0);

	# bail out on no results.
	if (scalar @list == 0) {
	    return 'no vandalised factoids... wooohoo.';
	}

	# parse the results.
	my $prefix = "Vandalised factoid ";
	return &formListReply(1, $prefix, @list);

    } elsif ($type =~ /^total$/i) {
        &status("factstats(total): starting...");
	my $start_time	= &timeget();
	my @list;
	my $str;
	my($i,$j);
	my %hash;

	### lets do it.
	# total factoids requests.
	$i = &sumKey("factoids", "requested_count");
	push(@list, "total requests - $i");

	# total factoids modified.
	$str = &countKeys("factoids", "modified_by");
	push(@list, "total modified - $str");

	# total factoids modified.
	$j	= &countKeys("factoids", "requested_count");
	$str	= &countKeys("factoids", "factoid_key");
	push(@list, "total non-requested - ".($str - $i));

	# average request/factoid.
	# i/j == total(requested_count)/count(requested_count)
	$str = sprintf("%.01f", $i/$j);
	push(@list, "average requested per factoid - $str");

	# total prepared for deletion.
	$str	= scalar( &searchTable("factoids", "factoid_key", "factoid_value", " #DEL") );
	push(@list, "total prepared for deletion - $str");

	# total unique authors.
	foreach ( &dbRawReturn("SELECT created_by FROM factoids WHERE created_by IS NOT NULL") ) {
	    /^(\S+)!/;
	    my $nick = lc $1;
	    $hash{$nick}++;
	}
	push(@list, "total unique authors - ".(scalar keys %hash) );
	undef %hash;

	# total unique requesters.
	foreach ( &dbRawReturn("SELECT requested_by FROM factoids WHERE requested_by IS NOT NULL") ) {
	    /^(\S+)!/;
	    my $nick = lc $1;
	    $hash{$nick}++;
	}
	push(@list, "total unique requesters - ".(scalar keys %hash) );
	undef %hash;

	### end of "job".

	my $delta_time	= &timedelta($start_time);
        &status(sprintf("factstats(broken): %.02f sec to retreive all factoids.", $delta_time)) if ($delta_time > 0);
	$start_time	= &timeget();

	# bail out on no results.
	if (scalar @list == 0) {
	    return 'no broken factoids... wooohoo.';
	}

	# parse the results.
	my $prefix = "General factoid stiatistics ";
	return &formListReply(1, $prefix, @list);

    } elsif ($type =~ /^deadredir$/i) {
	my @list = &searchTable("factoids", "factoid_key",
			"factoid_value", "^<REPLY> see ");
	my %redir;
	my $f;

	for (@list) {
	    my $factoid = $_;
	    my $val = &getFactInfo($factoid, "factoid_value");
	    if ($val =~ /^<REPLY> ?see( also)? (.*?)\.?$/i) {
		my $redirf = lc $2;
		my $redir = &getFactInfo($redirf, "factoid_value");
		next if (defined $redir);
		next if (length $val > 50);

		$redir{$redirf}{$factoid} = 1;
	    }
	}

	my @newlist;
	foreach $f (keys %redir) {
	    my @sublist = keys %{ $redir{$f} };
	    for (@sublist) {
		s/([\,\;]+)/\037$1\037/g;
	    }

	    push(@newlist, join(', ', @sublist)." => $f");
	}

	# parse the results.
	my $prefix = "Loose link (dead) redirections in factoids ";
	return &formListReply(1, $prefix, @newlist);

    } elsif ($type =~ /^dup(licate|e)$/i) {
        &status("factstats(dupe): starting...");
	my $start_time	= &timeget();
	my %hash	= &dbGetCol("factoids", "factoid_key,factoid_value", "factoid_value IS NOT NULL", 1);
	my $refs	= 0;
	my @list;
	my $v;

	foreach $v (keys %hash) {
	    my $count = scalar(keys %{ $hash{$v} });
	    next if ($count == 1);

	    my @sublist;
	    foreach (keys %{ $hash{$v} }) {
		if ($v =~ /^<REPLY> see /i) {
		    $refs++;
		    next;
		}

		s/([\,\;]+)/\037$1\037/g;
		if ($_ eq "") {
		    &WARN("dupe: _ = NULL. should never happen!.");
		    next;
		}
		push(@sublist, $_);
	    }

	    next unless (scalar @sublist);

	    push(@list, join(", ", @sublist));
	}

	&status("factstats(dupe): (good) dupe refs: $refs.");
	my $delta_time	= &timedelta($start_time);
        &status(sprintf("factstats(dupe): %.02f sec to complete", $delta_time)) if ($delta_time > 0);

	# bail out on no results.
	if (scalar @list == 0) {
	    return "no duplicate factoids... woohoo.";
	}

	# parse the results.
	my $prefix = "dupe factoid ";
	return &formListReply(1, $prefix, @list);

    } elsif ($type =~ /^nullfactoids$/i) {
	my $query = "SELECT factoid_key,factoid_value FROM factoids WHERE factoid_value=''";
	my $sth = $dbh->prepare($query);
	&ERROR("factstats(null): => '$query'.") unless $sth->execute;

	my @list;
	while (my @row = $sth->fetchrow_array) {
	    if ($row[1] ne "") {
		&DEBUG("row[1] != NULL for $row[0].");
		next;
	    }

	    &DEBUG("row[0] => '$row[0]'.");
	    push(@list, $row[0]);
	}
	$sth->finish;

	# parse the results.
	my $prefix = "NULL factoids (not deleted yet) ";
	return &formListReply(1, $prefix, @list);

    } elsif ($type =~ /^(2|too)short$/i) {
	# Custom select statement.
	my $query = "SELECT factoid_key,factoid_value FROM factoids WHERE length(factoid_value) <= 40";
	my $sth = $dbh->prepare($query);
	&ERROR("factstats(lame): => '$query'.") unless $sth->execute;

	my @list;
	while (my @row = $sth->fetchrow_array) {
	    my($key,$val) = ($row[0], $row[1]);
	    my $match = 0;
	    $match++ if ($val =~ /\s{3,}/);
	    next unless ($match);

	    my $v = &getFactoid($val);
	    if (defined $v) {
		&DEBUG("key $key => $val => $v");
	    }

	    $key =~ s/\,/\037\,\037/g;
	    push(@list, $key);
	}
	$sth->finish;

	# parse the results.
	my $prefix = "Lame factoids ";
	return &formListReply(1, $prefix, @list);

    } elsif ($type =~ /^listfix$/i) {
	# Custom select statement.
	my $query = "SELECT factoid_key,factoid_value FROM factoids";
	my $sth = $dbh->prepare($query);
	&ERROR("factstats(listfix): => '$query'.") unless $sth->execute;

	my @list;
	while (my @row = $sth->fetchrow_array) {
	    my($key,$val) = ($row[0], $row[1]);
	    my $match = 0;
	    $match++ if ($val =~ /\S+,? or \S+,? or \S+,? or \S+,?/);
	    next unless ($match);

	    $key =~ s/\,/\037\,\037/g;
	    push(@list, $key);
	    $val =~ s/,? or /, /g;
	    &DEBUG("fixed: => $val.");
	    &setFactInfo($key,"factoid_value", $val);
	}
	$sth->finish;

	# parse the results.
	my $prefix = "Inefficient lists fixed ";
	return &formListReply(1, $prefix, @list);

    } elsif ($type =~ /^locked$/i) {
	my %hash = &dbGetCol("factoids", "factoid_key,locked_by", "locked_by IS NOT NULL");
	my @list = keys %hash;

	for (@list) {
	    s/([\,\;]+)/\037$1\037/g;
	}

	my $prefix = "factoid statistics on $type ";
	return &formListReply(0, $prefix, @list);

    } elsif ($type =~ /^new$/i) {
	my %hash = &dbGetCol("factoids", "factoid_key,created_time", "created_time IS NOT NULL");
	my %age;

	foreach (keys %hash) {
	    my $created_time = $hash{$_};
	    my $delta_time   = time() - $created_time;
	    next if ($delta_time >= 60*60*24);

	    $age{$delta_time}{$_} = 1;
	}

	if (scalar keys %age == 0) {
	    return "sorry, no new factoids.";
	}

	my @list;
	foreach (sort {$a <=> $b} keys %age) {
	    push(@list, join(",", keys %{ $age{$_} }));
	}

	my $prefix = "new factoids in the last 24hours ";
	return &formListReply(0, $prefix, @list);

    } elsif ($type =~ /^part(ial)?dupe$/i) {
	### requires "custom" select statement... oh well...
	my $start_time	= &timeget();

	# form length|key and key=length hash list.
	&status("factstats(partdupe): forming length hash list.");
	my $query = "SELECT factoid_key,factoid_value,length(factoid_value) AS length FROM factoids WHERE length(factoid_value) >= 192 ORDER BY length";
	my $sth = $dbh->prepare($query);
	&ERROR("factstats(partdupe): => '$query'.") unless $sth->execute;

	my (@key, @list);
	my (%key, %length);
	while (my @row = $sth->fetchrow_array) {
	    $length{$row[2]}{$row[0]} = 1;	# length(value)|key.
	    $key{$row[0]} = $row[1];		# key=value.
	    push(@key, $row[0]);
	}
	$sth->finish;
	&status("factstats(partdupe): total keys => '". scalar(@key) ."'.");
	&status("factstats(partdupe): now deciphering data gathered");

	my @length = sort { $a <=> $b } keys %length;
	my $key;

	foreach $key (@key) {
	    shift @length if (length $key{$key} == $length[0]);

	    my $val = quotemeta $key{$key};
	    my @sublist;
	    my $length;
	    foreach $length (@length) {
		foreach (keys %{ $length{$length} }) {
		    if ($key{$_} =~ /^$val/i) {
			s/([\,\;]+)/\037$1\037/g;
			s/( and|and )/\037$1\037/g;
			push(@sublist,$key." and ".$_);
		    }
		}
	    }
	    push(@list, join(" ,",@sublist)) if (scalar @sublist);
	}

	my $delta_time = sprintf("%.02fs", &timedelta($start_time) );
        &status("factstats(partdupe): $delta_time sec to complete.") if ($delta_time > 0);

	# bail out on no results.
	if (scalar @list == 0) {
	    return "no initial partial duplicate factoids... woohoo.";
	}

	# parse the results.
	my $prefix = "initial partial dupe factoid ";
	return &formListReply(1, $prefix, @list);

    } elsif ($type =~ /^profanity$/i) {
	my %data = &dbGetCol("factoids", "factoid_key,factoid_value", "factoid_value IS NOT NULL");
	my @list;

	foreach (keys %data) {
	    push(@list, $_) if (&hasProfanity($_." ".$data{$_}));
	}

	# parse the results.
	my $prefix = "Profanity in factoids ";
	return &formListReply(1, $prefix, @list);

    } elsif ($type =~ /^redir(ection)?$/i) {
	my @list = &searchTable("factoids", "factoid_key",
			"factoid_value", "^<REPLY> see ");
	my %redir;
	my $f;

	for (@list) {
	    my $factoid = $_;
	    my $val = &getFactInfo($factoid, "factoid_value");
	    if ($val =~ /^<REPLY> see( also)? (.*?)\.?$/i) {
		my $redir	= lc $2;
		my $redirval	= &getFactInfo($redir, "factoid_value");
		if (defined $redirval) {
		    $redir{$redir}{$factoid} = 1;
		} else {
		    &WARN("factstats(redir): '$factoid' has loose link => '$redir'.");
		}
	    }
	}

	my @newlist;
	foreach $f (keys %redir) {
	    my @sublist = keys %{ $redir{$f} };
	    for (@sublist) {
		s/([\,\;]+)/\037$1\037/g;
	    }

	    push(@newlist, "$f => ". join(', ', @sublist));
	}

	# parse the results.
	my $prefix = "Redirections in factoids ";
	return &formListReply(1, $prefix, @newlist);

    } elsif ($type =~ /^request(ed)?$/i) {
	my %hash = &dbGetCol("factoids", "factoid_key,requested_count", "requested_count IS NOT NULL", 1);

	if (!scalar keys %hash) {
	    return 'sorry, no factoids have been questioned.';
	}

	my $count;
	my @list;
	my $total	= 0;
	foreach $count (sort {$b <=> $a} keys %hash) {
	    my @faqtoids = sort keys %{ $hash{$count} };

	    for (@faqtoids) {
		s/([\,\;]+)/\037$1\037/g;
	    }
	    $total	+= $count * scalar(@faqtoids);

	    push(@list, "$count - ". join(", ", @faqtoids));
	}
	unshift(@list, "\037$total - TOTAL\037");

	my $prefix = "factoid statistics on $type ";
	return &formListReply(0, $prefix, @list);

    } elsif ($type =~ /^reqrate$/i) {
	my %hash = &dbGetCol("factoids",
		"factoid_key,(unix_timestamp() - created_time)/requested_count as rate",
		"requested_by IS NOT NULL and created_time IS NOT NULL ORDER BY rate LIMIT 15", 1);

	my $rate;
	my @list;
	my $total	= 0;
	my $users	= 0;
	foreach $rate (sort { $b <=> $a } keys %hash) {
	    my $f	= join(", ", sort keys %{ $hash{$rate} });
	    my $str	= "$f - ".&Time2String($rate);
	    $str	=~ s/\002//g;
	    push(@list, $str);
	}

	my $prefix = "Rank of top factoid rate (time/req): ";
	return &formListReply(0, $prefix, @list);

    } elsif ($type =~ /^requesters?$/i) {
	my %hash = &dbGetCol("factoids", "factoid_key,requested_by", "requested_by IS NOT NULL");
	my %requester;

	foreach (keys %hash) {
	    my $thisnuh = $hash{$_};

	    $thisnuh =~ /^(\S+)!\S+@\S+$/;
	    $requester{lc $1}++;
	}

	if (!scalar keys %requester) {
	    return 'sorry, no factoids with requested_by field.';
	}

	# work-around.
	my %count;
	foreach (keys %requester) {
	    $count{ $requester{$_} }{$_} = 1;
	}
	undef %requester;

	my $count;
	my @list;
	my $total	= 0;
	my $users	= 0;
	foreach $count (sort { $b <=> $a } keys %count) {
	    my $requester = join(", ", sort keys %{ $count{$count} });
	    $total	+= $count * scalar(keys %{ $count{$count} });
	    $users	+= scalar(keys %{ $count{$count} });
	    push(@list, "$count by $requester");
	}
	unshift(@list, "\037$total TOTAL REQUESTS; $users UNIQUE REQUESTERS\037");
	# should not the above value be the same as collected by
	# 'requested'? soemthing weird is going on!

	my $prefix = "rank of top factoid requesters: ";
	return &formListReply(0, $prefix, @list);

    } elsif ($type =~ /^seefix$/i) {
	my @list = &searchTable("factoids", "factoid_key",
			"factoid_value", "^see ");
	my @newlist;
	my $fixed = 0;
	my %loop;
	my $f;

	for (@list) {
	    my $factoid = $_;
	    my $val = &getFactInfo($factoid, "factoid_value");
	
	    next unless ($val =~ /^see( also)? (.*?)\.?$/i);

	    my $redirf	= lc $2;
	    my $redir	= &getFactInfo($redirf, "factoid_value");

	    if ($redirf =~ /^\Q$factoid\W$/i) {
		&delFactoid($factoid);
		$loop{$factoid} = 1;
	    }

	    if (defined $redir) {	# good.
		&setFactInfo($factoid,"factoid_value","<REPLY> see $redir");
		$fixed++;
	    } else {
		push(@newlist, $redirf);
	    }
	}

	# parse the results.
	&msg($who, "Fixed $fixed factoids.");
	&msg($who, "Self looped factoids removed: ".
		sort(keys %loop) ) if (scalar keys %loop);

	my $prefix = "Loose link (dead) redirections in factoids ";
	return &formListReply(1, $prefix, @newlist);

    } elsif ($type =~ /^(2|too)long$/i) {
	my @list;

	# factoid_key.
	$query = "SELECT factoid_key FROM factoids WHERE length(factoid_key) >= $param{'maxKeySize'}";
	my $sth = $dbh->prepare($query);
	$sth->execute;
	while (my @row = $sth->fetchrow_array) {
	    push(@list,$row[0]);
	}

	# factoid_value.
	my $query = "SELECT factoid_key,factoid_value FROM factoids WHERE length(factoid_value) >= $param{'maxDataSize'}";
	$sth = $dbh->prepare($query);
	$sth->execute;
	while (my @row = $sth->fetchrow_array) {
	    push(@list,sprintf("\002%s\002 - %s", length($row[1]), $row[0]));
	}

	if (scalar @list == 0) {
	    return "good. no factoids exceed length.";
	}

	# parse the results.
	my $prefix = "factoid key||value exceeding length ";
	return &formListReply(1, $prefix, @list);

    } elsif ($type =~ /^unrequest(ed)?$/i) {
	my @list = &dbRawReturn("SELECT factoid_key FROM factoids WHERE requested_count IS NULL");

	for (@list) {
	    s/([\,\;]+)/\037$1\037/g;
	}

	my $prefix = "Unrequested factoids ";
	return &formListReply(0, $prefix, @list);
    }

    return "error: invalid type => '$type'.";
}

sub CmdListAuth {
    my ($query) = @_;
    my @list = &searchTable("factoids","factoid_key", "created_by", "^$query!");

    my $prefix = "factoid author list by '$query' ";
    &performStrictReply( &formListReply(1, $prefix, @list) );
}

1;
