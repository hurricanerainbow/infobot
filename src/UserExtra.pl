#
# UserExtra.pl: User Commands, Public.
#       Author: dms
#      Version: v0.2b (20000707)
#      Created: 20000107
#

if (&IsParam("useStrict")) { use strict; }

use vars qw($message $arg $qWord $verb $lobotomized);
use vars qw(%channels %chanstats %cmdstats);

###
### Start of command hooks for UserExtra.
###

&addCmdHook("main", 'chan(stats|info)', ('CODEREF' => 'chaninfo', ) );
&addCmdHook("main", 'cmd(stats|info)', ('CODEREF' => 'cmdstats', ) );
&addCmdHook("main", 'factinfo', ('CODEREF' => 'factinfo', 
	'Cmdstats' => 'Factoid Info', Module => 'factoids', ) );
&addCmdHook("main", 'factstats?', ('CODEREF' => 'factstats', 
	'Cmdstats' => 'Factoid Statistics', Help => "factstats", 
	Forker => 1, 'Identifier' => 'factoids', ) );
&addCmdHook("main", 'help', ('CODEREF' => 'help', 
	'Cmdstats' => 'Help', ) );
&addCmdHook("main", 'karma', ('CODEREF' => 'karma', ) );
&addCmdHook("main", 'ignorelist', ('CODEREF' => 'ignorelist', ) );
&addCmdHook("main", 'i?spell', ('CODEREF' => 'ispell', 
	Help => 'spell', Identifier => 'spell', ) );
&addCmdHook("main", 'd?nslookup', ('CODEREF' => 'DNS', 
	Help => 'nslookup', Identifier => 'allowDNS',
	Forker => "NULL", ) );
&addCmdHook("main", 'tell|explain', ('CODEREF' => 'tell', 
	Help => 'tell', Identifier => 'allowTelling', ) );


&status("CMD: loaded ".scalar(keys %hooks_main)." MAIN command hooks.");

###
### Start of commands for hooks.
###

sub chaninfo {
    my $chan = lc shift(@_);
    my $mode;

    if ($chan eq "") {		# all channels.
	my $count	= 0;
	my $i		= keys %channels;
	my $reply	= "i am on \002$i\002 ".&fixPlural("channel",$i);
	my @array;

	### line 1.
	foreach (sort keys %channels) {
	    if (/^\s*$/ or / /) {
		&status("chanstats: fe channels: chan == NULL.");
		&ircCheck();
		next;
	    }
	    push(@array, "$_ (".scalar(keys %{$channels{$_}{''}}).")");
	}
	&performStrictReply($reply.": ".join(' ', @array));

	### line 2.
	foreach $chan (keys %channels) {
	    # crappy debugging...
	    # TODO: use $mask{chan} instead?
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
    $chanstats{$chan}{'Join'}		||= 0;
    $chanstats{$chan}{'SignOff'}	||= 0;
    $chanstats{$chan}{'Part'}		||= 0;

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
}

# Command statistics.
sub cmdstats {
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
}

# Factoid extension info. xk++
sub factinfo {
    my $faqtoid = lc shift(@_);
    my $query   = "";

    if ($faqtoid =~ /^\-(\S+)(\s+(.*))$/) {
	&msg($who,"error: individual factoid info queries not supported as yet.");
	&msg($who,"it's possible that the factoid mistakenly begins with '-'.");
	return $noreply;

	$query   = lc $1;
	$faqtoid = lc $3;
    }

    &CmdFactInfo($faqtoid, $query);
}

sub factstats {
    my $type = shift(@_);

    &Forker("factoids", sub {
	&performStrictReply( &CmdFactStats($type) );
    } );
}

sub karma {
    my $target	= lc( shift || $who );
    my $karma	= &dbGet("karma", "nick",$target,"karma") || 0;

    if ($karma != 0) {
	&performStrictReply("$target has karma of $karma");
    } else {
	&performStrictReply("$target has neutral karma");
    }
}

sub ignorelist {
    &status("$who asked for the ignore list");

    my $time	= time();
    my $count	= scalar(keys %ignoreList);
    my $counter	= 0;
    my @array;

    if ($count == 0) {
	&performStrictReply("no one in the ignore list!!!");
	return;
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
}

sub ispell {
    my $query = shift;

    if (! -x "/usr/bin/spell") {
	&msg($who, "no binary found.");
	return;
    }

    if (!&validExec($query)) {
	&msg($who,"argument appears to be fuzzy.");
	return;
    }

    my $reply = "I can't find alternate spellings for '$query'";

    foreach (`/bin/echo '$query' | /usr/bin/ispell -a -S`) {
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
}

sub nslookup {
    my $query = shift;
    &status("DNS Lookup: $query");
    &DNS($query);
}

sub tell {
    my $args = shift;
    my ($target, $tell_obj) = ('','');
    my $reply;

    ### is this fixed elsewhere?
    $args =~ s/\s+/ /g;		# fix up spaces.
    $args =~ s/^\s+|\s+$//g;	# again.

    # this one catches most of them
    if ($args =~ /^(\S+) about (.*)$/i) {
	$target		= lc $1;
	$tell_obj	= $2;

	$tell_obj	= $who	if ($tell_obj =~ /^(me|myself)$/i);
	$query		= $tell_obj;
    } elsif ($args =~ /^(\S+) where (\S+) can (\S+) (.*)$/i) {
	# i'm sure this could all be nicely collapsed
	$target		= lc $1;
	$tell_obj	= $4;
	$query		= $tell_obj;

    } elsif ($args =~ /^(\S+) (what|where) (.*?) (is|are)[.?!]*$/i) {
	$target		= lc $1;
	$qWord		= $2;
	$tell_obj	= $3;
	$verb		= $4;
	$query		= "$qWord $verb $tell_obj";

    } elsif ($args =~ /^(.*?) to (\S+)$/i) {
	$target		= lc $3;
	$tell_obj	= $2;
	$query		= $tell_obj;
    }

    # check target type. Deny channel targets.
    if ($target !~ /^$mask{nick}$/ or $target =~ /^$mask{chan}$/) {
	&msg($who,"No, $who, I won't. (target invalid?)");
	return;
    }

    $target	= $talkchannel  if ($target =~ /^us$/i);
    $target	= $who		if ($target =~ /^(me|myself)$/i);

    &status("target: $target query: $query");  

    # "intrusive".
    if ($target !~ /^$mask{chan}$/ and !&IsNickInAnyChan($target)) {
	&msg($who, "No, $target is not in any of my chans.");
	return $noreply;
    }

    ### TODO: don't "tell" if sender is not in target's channel.

    # self.
    if ($target eq $ident) {	# lc?
	&msg($who, "Isn't that a bit silly?");
	return $noreply;
    }

    # ...
    my $result = &doQuestion($tell_obj);
    return if ($result eq $noreply);

    # no such factoid.
    if ($result eq "") {
	&msg($who, "i dunno what is '$tell_obj'.");
	return;
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
}

sub DNS {
    my $dns = shift;
    my($match, $x, $y, $result);
    my $pid;

    if ($dns =~ /(\d+\.\d+\.\d+\.\d+)/) {
	&status("DNS query by IP address: $in");
	$match = $1;
	$y = pack('C4', split(/\./, $match));
	$x = (gethostbyaddr($y, &AF_INET));

	if ($x !~ /^\s*$/) {
	    $result = $match." is ".$x unless ($x =~ /^\s*$/);
	} else {
	    $result = "I can't seem to find that address in DNS";
        }
    } else {
	&status("DNS query by name: $in");
	$x = join('.',unpack('C4',(gethostbyname($in))[4]));

	if ($x !~ /^\s*$/) {
	    $result = $in." is ".$x;
	} else {
	    $result = "I can\'t find that machine name";
	}
    }

    &performReply($result);
}


###
### amalgamated commands.
###

sub userCommands {
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
###	&ScheduleThis(5, "getNickInUse") if (@_);
	&status("Schedule rejoin in 5secs to $chan by $who.");
	$conn->schedule(5, sub { &joinchan($chan); });

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

    # cpustats.
    if ($message =~ /^cpustats$/i) {
	if ($^O !~ /linux/) {
	    &ERROR("cpustats: your OS is not supported yet.");
	    return $noreply;
	}

	### poor method to get info out of file, please fix.
	open(STAT,"/proc/$$/stat");
	my $line = <STAT>;
	chop $line;
	my @data = split(/ /, $line);
	close STAT;

	# utime(13) + stime(14).
	my $cpu_usage	= sprintf("%.01f", ($data[13]+$data[14]) / 100 );
	my $time	= time() - $^T;
	my $raw_perc	= $cpu_usage*100/$time;
	my $perc;

	if ($raw_perc > 1) {
	    $perc	= sprintf("%.01f", $raw_perc);
	} elsif ($raw_perc > 0.1) {
	    $perc	= sprintf("%.02f", $raw_perc);
	} else {			# <=0.1
	    $perc	= sprintf("%.03f", $raw_perc);
	}

	&performStrictReply("Total CPU usage: $cpu_usage s ... Percentage CPU used: $perc %");
	&DEBUG("15 => $data[15] (cutime)");
	&DEBUG("16 => $data[16] (cstime)");

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
	  " and \002$count{'Moron'}\002 ".
		&fixPlural("moron",$count{'Moron'}).
	  ".  I have been awake for $upString this session, and ".
	  "currently reference \002$count\002 factoids.  ".
	  "I'm using about \002$memusage\002 ".
	  "kB of memory."
	);

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
