#
# UserExtra.pl: User Commands, Public.
#       Author: dms
#      Version: v0.2b (20000707)
#      Created: 20000107
#

if (&IsParam("useStrict")) { use strict; }

use vars qw($message $arg $qWord $verb $lobotomized);
use vars qw(%channels %chanstats %cmdstats);

sub userCommands {
    return '' unless ($addressed);

    # chaninfo. xk++.
    if ($message =~ /^chan(stats|info)(\s+(\S+))?$/i) {
	my $chan = lc $3;
	my $mode;

	if ($chan eq "") {		# all channels.
	    my $count = 0;
	    my $i = keys %channels;

	    &performStrictReply(
		"i am on \002$i\002 ". &fixPlural("channel",$i).
		": ". join(' ', sort keys %channels)
	    );

	    foreach $chan (keys %channels) {
		# crappy debugging...
		if ($chan =~ / /) {
		    &ERROR("bad channel: chan => '$chan'.");
		}
		$count += scalar(keys %{$channels{$chan}{''}});
	    }
	    &performStrictReply(
		"i've cached \002$count\002 ".&fixPlural("user",$count).
		" distributed over \002".scalar(keys %channels)."\002 ".
		&fixPlural("channel",scalar(keys %channels))."."
	    );

	    return $noreply;
	}

	# channel specific.

	if (&validChan($chan) == 0) {
	    &msg($who,"error: invalid channel \002$chan\002");
	    return $noreply;
	}

	# Step 1:
	my @array;
	foreach (sort keys %{$chanstats{$chan}}) {
	    my $int = $chanstats{$chan}{$_};
	    next unless ($int);

	    push(@array, "\002$int\002 ". &fixPlural($_,$int));
	}
	my $reply = "On \002$chan\002, there ".
		&fixPlural("has",scalar(@array)). " been ".
		&IJoin(@array);

	# Step 1b: check channel inconstencies.
	$chanstats{$chan}{'Join'}	||= 0;
	$chanstats{$chan}{'SignOff'}	||= 0;
	$chanstats{$chan}{'Part'}	||= 0;

	my $delta_stats = $chanstats{$chan}{'Join'}
		- $chanstats{$chan}{'SignOff'}
		- $chanstats{$chan}{'Part'};

	if ($delta_stats) {
	    my $total = scalar(keys %{$channels{$chan}{''}});
	    &status("chaninfo: join ~= signoff + part (drift of $delta_stats < $total).");

	    if ($delta_stats > $total) {
		&ERROR("chaninfo: delta_stats exceeds total users.");
	    }
	}

	# Step 2:
	undef @array;
	my $type;
	foreach ("v","o","") {
	    my $int = scalar(keys %{$channels{$chan}{$_}});
	    next unless ($int);

	    $type = "Voice" if ($_ eq "v");
	    $type = "Opped" if ($_ eq "o");
	    $type = "Total" if ($_ eq "");

	    push(@array,"\002$int\002 $type");
	}
	$reply .= ".  At the moment, ". &IJoin(@array);

	# Step 3:
	### TODO: what's wrong with the following?
	my %new = map { $userstats{$_}{'Count'} => $_ } keys %userstats;
	my($count) = (sort { $b <=> $a } keys %new)[0];
	if ($count) {
	    $reply .= ".  \002$new{$count}\002 has said the most with a total of \002$count\002 messages";
	}
	&performStrictReply("$reply.");

	return $noreply;
    }

    # Command statistics.
    if ($message =~ /^cmdstats$/i) {
	my @array;

	if (!scalar(keys %cmdstats)) {
	    &performReply("no-one has run any commands yet");
	    return $noreply;
	}

	my %countstats;
	foreach (keys %cmdstats) {
	    $countstats{$cmdstats{$_}}{$_} = 1;
	}

	foreach (sort {$b <=> $a} keys %countstats) {
	    my $int = $_;
	    next unless ($int);

	    foreach (keys %{$countstats{$int}}) {
		push(@array, "\002$int\002 of $_");
	    }
	}
	&performStrictReply("command usage include ". &IJoin(@array).".");

	return $noreply;
    }

    # conversion: ascii.
    if ($message =~ /^(asci*|chr) (\d+)$/) {
	return '' unless (&IsParam("allowConv"));

	$arg = $2;
	if ($arg < 32) {
	    $arg += 64;
	    $result = "^".chr($arg);
	} else {
	    $result = chr($2);
	}
	$result = "NULL"	if ($arg == 0);

	&performReply( sprintf("ascii %s is '%s'", $arg, $result) );
	return $noreply;
    }

    # conversion: ord.
    if ($message =~ /^ord (.)$/) {
	return '' unless (&IsParam("allowConv"));

	$arg = $1;
	if (ord($arg) < 32) {
	    $arg = chr(ord($arg) + 64);
	    if ($arg eq chr(64)) {
		$arg = 'NULL';
	    } else {
		$arg = '^'.$arg;
	    }
	}

	&performReply( sprintf("'%s' is ascii %s", $arg, ord $1) );
	return $noreply;
    }

    # hex.
    if ($message =~ /^hex(\s+(.*))?$/i) {
	my $arg = $2;

	if (!defined $arg) {
	    &help("hex");
	    return $noreply;
	}

	if (length $arg > 80) {
	    &msg($who, "Too long.");
	    return $noreply;
	}

	my $retval;
	foreach (split //, $arg) {
	    $retval .= sprintf(" %X", ord($_));
	}

	&performStrictReply("$arg is$retval");

	return $noreply;
    }

    # crypt.
    if ($message =~ /^crypt\s+(\S+)\s*(?:,| )\s*(\S+)/) {
	# word salt.
	&performStrictReply(crypt($1, $2));
	return $noreply;
    }

    # Factoid extension info. xk++
    if ($message =~ /^(factinfo)(\s+(.*))?$/i) {
	my $query   = "";
	my $faqtoid = lc $3;

	if ($faqtoid =~ /^\-(\S+)(\s+(.*))$/) {
	    &msg($who,"error: individual factoid info queries not supported as yet.");
	    &msg($who,"it's possible that the factoid mistakenly begins with '-'.");
	    return $noreply;

	    $query   = lc $1;
	    $faqtoid = lc $3;
	}

	&loadMyModule($myModules{'factoids'});
	&CmdFactInfo($faqtoid, $query);
	
	$cmdstats{'Factoid Info'}++;
	return $noreply;
    }

    # Factoid extension statistics. xk++
    if ($message =~ /^(factstats?)(\s+(\S+))?$/i) {
	my $type	= $3;

	if (!defined $type) {
	    &help("factstats");
	    return $noreply;
	}

	&Forker("factoids", sub {
		&performStrictReply( &CmdFactStats($type) );
	} );
	$cmdstats{'Factoid Statistics'}++;
	return $noreply;
    }

    # help.
    if ($message =~ /^help(\s+(.*))?$/i) {
	$cmdstats{'Help'}++;

	&help($2);

	return $noreply;
    }

    # karma.
    if ($message =~ /^karma(\s+(\S+))?\??$/i) {
	return '' unless (&IsParam("karma"));

	my $target = lc $2 || lc $who;

	my $karma = &dbGet("karma", "nick",$target,"karma") || 0;
	if ($karma != 0) {
	    &performStrictReply("$target has karma of $karma");
	} else {
	    &performStrictReply("$target has neutral karma");
	}

	return $noreply;
    }

    # ignorelist.
    if ($message =~ /^ignorelist$/i) {
	&status("$who asked for the ignore list");

	my $time = time();
	my $count = scalar(keys %ignoreList);
	my $counter = 0;
	my @array;

	if ($count == 0) {
	    &performStrictReply("no one in the ignore list!!!");
	    return $noreply;
	}

	foreach (sort keys %ignoreList) {
	    my $str;

	    if ($ignoreList{$_} != 1) {	# temporary ignore.
		my $expire = $ignoreList{$_} - $time;
		if (defined $expire and $expire < 0) {
		    &status("ignorelist: deleting $_.");
		    delete $ignoreList{$_};
		} else {
		    $str = "$_ (". &Time2String($expire) .")";
		}
	    } else {
		$str = $_;
	    }

	    push(@array,$str);
	    $counter++;
	    if (scalar @array >= 8 or $counter == $count) {
		&msg($who, &formListReply(0, "Ignore list ", @array) );
		@array = ();
	    }
	}

	return $noreply;
    }

    # ispell.
    if ($message =~ /^spell(\s+(.*))?$/) {
	return '' unless (&IsParam("spell"));
	my $query = $2;

	if ($query eq "") {
	    &help("spell");
	    return $noreply;
	}

	if (! -x "/usr/bin/spell") {
	    &msg($who, "no binary found.");
	    return $noreply;
	}

	if (!&validExec($query)) {
	    &msg($who,"argument appears to be fuzzy.");
	    return $noreply;
	}

	my $reply = "I can't find alternate spellings for '$query'";

	foreach (`echo '$query' | ispell -a -S`) {
	    chop;
	    last if !length;		# end of query.

	    if (/^\@/) {		# intro line.
		next;
	    } elsif (/^\*/) {		# possibly correct.
		$reply = "'$query' may be spelled correctly";
		last;
	    } elsif (/^\&/) {		# possible correction(s).
		s/^\& (\S+) \d+ \d+: //;
		my @array = split(/,? /);

		$reply = "possible spellings for $query: @array";
		last;
	    } elsif (/^\+/) {
		&DEBUG("spell: '+' found => '$_'.");
		last;
	    } else {
		&DEBUG("spell: unknown: '$_'.");
	    }
	}

	&performStrictReply($reply);

	return $noreply;
    }

    # nslookup.
    if ($message =~ /^(dns|nslookup)(\s+(\S+))?$/i) {
	return '' unless (&IsParam("allowDNS"));

	if ($3 eq "") {
	    &help("nslookup");
	    return $noreply;
	}

	&status("DNS Lookup: $3");
	&loadMyModule($myModules{'allowDNS'});
	&DNS($3);
	return $noreply;
    }

    # cycle.
    if ($message =~ /^(cycle)(\s+(\S+))?$/i) {
	return $noreply unless (&hasFlag("o"));
	my $chan = lc $3;

	if ($chan eq "") {
	    if ($msgType =~ /public/) {
		$chan = $talkchannel;
		&DEBUG("cycle: setting chan to '$chan'.");
	    } else {
		&help("cycle");
		return $noreply;
	    }
	}

	if (&validChan($chan) == 0) {
	    &msg($who,"error: invalid channel \002$chan\002");
	    return $noreply;
	}

	&msg($chan, "I'm coming back. (courtesy of $who)");
	&part($chan);
	sleep 3;
	&joinchan($chan);

	return $noreply;
    }

    # redir.
    if ($message =~ /^redir(\s+(.*))?/i) {
	return $noreply unless (&hasFlag("o"));
	my $factoid = $2;

	if (!defined $factoid) {
	    &help("redir");
	    return $noreply;
	}

	my $val  = &getFactInfo($factoid, "factoid_value");
	if (!defined $val or $val eq "") {
	    &msg($who, "error: '$factoid' does not exist.");
	    return $noreply;
	}
	&DEBUG("val => '$val'.");
	my @list = &searchTable("factoids", "factoid_key",
					"factoid_value", "^$val\$");

	if (scalar @list == 1) {
	    &msg($who, "hrm... '$factoid' is unique.");
	    return $noreply;
	}
	if (scalar @list > 5) {
	    &msg($who, "A bit too many factoids to be redirected, hey?");
	    return $noreply;
	}

	my @redir;
	&status("Redirect '$factoid' (". ($#list) .")...");
	for (@list) {
	    next if (/^\Q$factoid\E$/i);

	    &status("  Redirecting '$_'.");
	    my $was = &getFactoid($_);
	    &DEBUG("  was '$was'.");
	    push(@redir,$_);
	    &setFactInfo($_, "factoid_value", "<REPLY> see $factoid");
	}
	&status("Done.");

	&msg($who, &formListReply(0, "'$factoid' is redirected to by '", @redir));

	return $noreply;
    }

    # rot13 it.
    if ($message =~ /^rot13(\s+(.*))?/i) {
	my $reply = $2;

	if ($reply eq "") {
	    &help("rot13");
	    return $noreply;
	}

	$reply =~ y/A-Za-z/N-ZA-Mn-za-m/;
	&performStrictReply($reply);

	return $noreply;
    }

    # ircstats.
    if ($message =~ /^ircstats$/i) {
	my $count	= $ircstats{'ConnectCount'};
	my $format_time	= &Time2String(time() - $ircstats{'ConnectTime'});
	my $reply;

	foreach (keys %ircstats) {
	    &DEBUG("ircstats: $_ => '$ircstats{$_}'.");
	}

	### RECONNECT COUNT.
	if ($count == 1) {	# good.
	    $reply = "I'm connected to $ircstats{'Server'} and have been so".
		" for $format_time";
	} else {
	    $reply = "Currently I'm hooked up to $ircstats{'Server'} but only".
		" for $format_time.  ".
		"I had to reconnect \002$count\002 times.";
	}

	### REASON.
	my $reason = $ircstats{'DisconnectReason'};
	if (defined $reason) {
	    $reply .= "  I was last disconnected for '$reason'.";
	}

	&performStrictReply($reply);
		
	return $noreply;
    }

    # status.
    if ($message =~ /^statu?s$/i) {
	my $startString	= scalar(localtime $^T);
	my $upString	= &Time2String(time() - $^T);
	my $count	= &countKeys("factoids");

	&performStrictReply(
	"Since $startString, there have been".
	  " \002$count{'Update'}\002 ".
		&fixPlural("modification", $count{'Update'}).
	  " and \002$count{'Question'}\002 ".
		&fixPlural("question",$count{'Question'}).
	  " and \002$count{'Dunno'}\002 ".
		&fixPlural("dunno",$count{'Dunno'}).
	  ".  I have been awake for $upString this session, and ".
	  "currently reference \002$count\002 factoids.  ".
	  "I'm using about \002$memusage\002 ".
	  "kB of memory."
	);

	return $noreply;
    }

    # tell.
    if ($message =~ /^(tell|explain)(\s+(.*))?$/) {
	return '' unless (&IsParam("allowTelling"));

	my $args = $3;
	if (!defined $args) {
	    &help("tell");
	    return $noreply;
	}

	my ($target, $tell_obj) = ('','');
	my $reply;

	# this one catches most of them
	if ($message =~ /^tell\s+(\S+)\s+about\s+(.*)/i) {
	    $target	= lc $1;
	    $tell_obj	= $2;

	    # required for privmsg if excessive size.(??)
	    if ($target =~ /^us$/i) {
		$target = $talkchannel;
	    } elsif ($target =~ /^(me|myself)$/i) {
		$target	= $who;
	    }

	    $tell_obj	= $who	if ($tell_obj =~ /^(me|myself)$/i);
	    $query	= $tell_obj;
        } elsif ($message =~ /tell\s+(\S+)\s+where\s+(\S+)\s+can\s+(\S+)\s+(.*)/i) {
	    # i'm sure this could all be nicely collapsed
	    $target	= lc $1;
	    $tell_obj	= $4;
	    $query	= $tell_obj;

	    $target	= ""	if ($target =~ /^us$/i);
        } elsif ($message =~ /tell\s+(\S+)\s+(what|where)\s+(.*?)\s+(is|are)[.?!]*$/i) {
	    $target	= lc $1;
	    $qWord	= $2;
	    $tell_obj	= $3;
	    $verb	= $4;
	    $query	= "$qWord $verb $tell_obj";

	    $target	= ""	if ($target =~ /^us$/i);
	} elsif ($message =~ /^(explain|tell)\s+(\S+)\s+to\s+(.*)$/i) {
	    $target	= lc $3;
	    $tell_obj	= $2;
	    $query	= $tell_obj;
	    $target	= ""	if ($target =~ /^us$/i);
        }
	&status("target: $target query: $query");  

	# check target type. Deny channel targets.
	if ($target !~ /^$mask{nick}$/ or $target =~ /^$mask{chan}$/) {
	    &msg($who,"No, $who, I won't.");
	    return $noreply;
	}

	# "intrusive".
	if (!&IsNickInAnyChan($target)) {
	    &msg($who, "No, $target is not in any of my chans.");
	    return $noreply;
	}

	### TODO: don't "tell" if sender is not in target's channel.

	# self.
	if ($target eq $ident) {
	    &msg($who, "Isn't that a bit silly?");
	    return $noreply;
	}

	# ...
	my $result = &doQuestion($tell_obj);
	return $noreply if ($result eq $noreply);

	# no such factoid.
	if ($result eq "") {
	    &msg($who, "i dunno what is '$tell_obj'.");
	    return $noreply;
	}

	# success.
	&status("tell: <$who> telling $target about $tell_obj.");
	if ($who ne $target) {
	    &msg($who, "told $target about $tell_obj ($result)");
	    $reply = "$who wants you to know: $result";
	} else {
	    $reply = "telling yourself: $result";
	}

	&msg($target, $reply);

	return $noreply;
    }

    # wantNick. xk++
    if ($message =~ /^wantNick$/i) {
	if ($param{'ircNick'} eq $ident) {
	    &msg($who, "I hope you're right. I'll try anyway.");
	}

	my $str = "attempting to change nick to $param{'ircNick'}";
	&status($str);
	&msg($who, $str);

	&nick($param{'ircNick'});
	return $noreply;
    }

    # what else...
}

1;
