#
# UserExtra.pl: User Commands, Public.
#       Author: dms
#      Version: v0.2b (20000707)
#      Created: 20000107
#

#use strict;
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
&addCmdHook("main", 'i?spell', ('CODEREF' => 'ispell', 
	Help => 'spell', Identifier => 'spell', ) );
&addCmdHook("main", 'd?nslookup', ('CODEREF' => 'DNS', 
	Help => 'nslookup', Identifier => 'allowDNS',
	Forker => "NULL", ) );
&addCmdHook("main", 'tell|explain', ('CODEREF' => 'tell', 
	Help => 'tell', Identifier => 'allowTelling',
	Cmdstats => 'Tell') );
&addCmdHook("main", 'news', ('CODEREF' => 'News::Parse', 
	Module => 'news', 'Cmdstats' => 'News' ) );
&addCmdHook("main", 'countrystats', ('CODEREF' => 'countryStats', 
#	Forker => "NULL",
 ) );

&status("CMD: loaded ".scalar(keys %hooks_main)." MAIN command hooks.");

###
### Start of commands for hooks.
###

sub chaninfo {
    my $chan = lc shift(@_);
    my $mode;

    if ($chan eq "") {		# all channels.
	my $i		= keys %channels;
	my $reply	= "i am on \002$i\002 ".&fixPlural("channel",$i);
	my $tucount	= 0;	# total user count.
	my $uucount	= 0;	# unique user count.
	my @array;

	### line 1.
	foreach (sort keys %channels) {
	    if (/^\s*$/ or / /) {
		&status("chanstats: fe channels: chan == NULL.");
		&ircCheck();
		next;
	    }
	    push(@array, "$_ (".scalar(keys %{ $channels{$_}{''} }).")");
	}
	&pSReply($reply.": ".join(' ', @array));

	### total user count.
	foreach $chan (keys %channels) {
	    $tucount += scalar(keys %{ $channels{$chan}{''} });
	}

	### unique user count.
	my @nicks;
	foreach $chan (keys %channels) {
	    foreach (keys %{ $channels{$chan}{''} }) {
		next if (grep /^\Q$_\E$/, @nicks);
		$uucount++;
		push(@nicks, $_);
	    }
	}
	&DEBUG("nicks => '".scalar(@nicks)."'...");
	if (scalar @nicks != $uucount) {
	    &DEBUG("nicks != uucount...");
	}

	my $chans = scalar(keys %channels);
	&pSReply(
	    "i've cached \002$tucount\002 ". &fixPlural("user",$tucount).
	    ", \002$uucount\002 unique ". &fixPlural("user",$uucount).
	    ", distributed over \002$chans\002 ".
	    &fixPlural("channel", $chans)."."
	);

	return;
    }

    # channel specific.

    if (&validChan($chan) == 0) {
	&msg($who,"error: invalid channel \002$chan\002");
	return;
    }

    # Step 1:
    my @array;
    foreach (sort keys %{ $chanstats{$chan} }) {
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
	my $total = scalar(keys %{ $channels{$chan}{''} });
	&status("chaninfo: join ~= signoff + part (drift of $delta_stats < $total).");

	if ($delta_stats > $total) {
	    &ERROR("chaninfo: delta_stats exceeds total users.");
	}
    }

    # Step 2:
    undef @array;
    my $type;
    foreach ("v","o","") {
	my $int = scalar(keys %{ $channels{$chan}{$_} });
	next unless ($int);

	$type = "Voice" if ($_ eq "v");
	$type = "Opped" if ($_ eq "o");
	$type = "Total" if ($_ eq "");

	push(@array,"\002$int\002 $type");
    }
    $reply .= ".  At the moment, ". &IJoin(@array);

    # Step 3:
    my %new;
    foreach (keys %userstats) {
	next unless (exists $userstats{$_}{'Count'});
	if ($userstats{$_}{'Count'} =~ /^\D+$/) {
	    &WARN("userstats{$_}{Count} is non-digit.");
	    next;
	}

	$new{$_} = $userstats{$_}{'Count'};
    }

    # todo: show top 3 with percentages?
    my($count) = (sort { $new{$a} <=> $new{$b} } keys %new)[0];
    if ($count) {
	$reply .= ".  \002$count\002 has said the most with a total of \002$new{$count}\002 messages";
    }
    &pSReply("$reply.");
}

# Command statistics.
sub cmdstats {
    my @array;

    if (!scalar(keys %cmdstats)) {
	&performReply("no-one has run any commands yet");
	return;
    }

    my %countstats;
    foreach (keys %cmdstats) {
	$countstats{ $cmdstats{$_} }{$_} = 1;
    }

    foreach (sort {$b <=> $a} keys %countstats) {
	my $int = $_;
	next unless ($int);

	foreach (keys %{ $countstats{$int} }) {
	    push(@array, "\002$int\002 of $_");
	}
    }
    &pSReply("command usage include ". &IJoin(@array).".");
}

# Factoid extension info. xk++
sub factinfo {
    my $faqtoid = lc shift(@_);
    my $query   = "";

    if ($faqtoid =~ /^\-(\S+)(\s+(.*))$/) {
	&msg($who,"error: individual factoid info queries not supported as yet.");
	&msg($who,"it's possible that the factoid mistakenly begins with '-'.");
	return;

	$query   = lc $1;
	$faqtoid = lc $3;
    }

    &CmdFactInfo($faqtoid, $query);
}

sub factstats {
    my $type = shift(@_);

    &Forker("factoids", sub {
	&pSReply( &CmdFactStats($type) );
    } );
}

sub karma {
    my $target	= lc( shift || $who );
    my $karma	= &dbGet("stats", "counter", "nick=".
			&dbQuote($target)." AND type='karma'") || 0; 

    if ($karma != 0) {
	&pSReply("$target has karma of $karma");
    } else {
	&pSReply("$target has neutral karma");
    }
}

sub ispell {
    my $query = shift;

    if (! -x "/usr/bin/ispell") {
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
	} elsif (/^# (.*?) 0$/) {
	    # none found.
	    last;
	} else {
	    &DEBUG("spell: unknown: '$_'.");
	}
    }

    &pSReply($reply);
}

sub nslookup {
    my $query = shift;
    &status("DNS Lookup: $query");
    &DNS($query);
}

sub tell {
    my $args = shift;
    my ($target, $tell_obj) = ('','');
    my $dont_tell_me	= 0;
    my $reply;

    ### is this fixed elsewhere?
    $args =~ s/\s+/ /g;		# fix up spaces.
    $args =~ s/^\s+|\s+$//g;	# again.

    # this one catches most of them
    if ($args =~ /^(\S+) (-?)about (.*)$/i) {
	$target		= $1;
	$tell_obj	= $3;
	$dont_tell_me	= ($2) ? 1 : 0;

	$tell_obj	= $who	if ($tell_obj =~ /^(me|myself)$/i);
	$query		= $tell_obj;
    } elsif ($args =~ /^(\S+) where (\S+) can (\S+) (.*)$/i) {
	# i'm sure this could all be nicely collapsed
	$target		= $1;
	$tell_obj	= $4;
	$query		= $tell_obj;

    } elsif ($args =~ /^(\S+) (what|where) (.*?) (is|are)[.?!]*$/i) {
	$target		= $1;
	$qWord		= $2;
	$tell_obj	= $3;
	$verb		= $4;
	$query		= "$qWord $verb $tell_obj";

    } elsif ($args =~ /^(.*?) to (\S+)$/i) {
	$target		= $3;
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

    &status("tell: target = $target, query = $query");  

    # "intrusive".
#    if ($target !~ /^$mask{chan}$/ and !&IsNickInAnyChan($target)) {
#	&msg($who, "No, $target is not in any of my chans.");
#	return;
#    }

    # self.
    if ($target =~  /^\Q$ident\E$/i) {
	&msg($who, "Isn't that a bit silly?");
	return;
    }

    my $oldwho		= $who;
    my $oldmtype	= $msgType;
    $who		= $target;
    my $result = &doQuestion($tell_obj);
	# ^ returns '0' if nothing was found.
    $who		= $oldwho;

    # no such factoid.
    if (!defined $result || $result =~ /^0?$/) {
	$who		= $target;
	$msgType	= "private";

	# support command redirection.
	# recursive cmdHooks aswell :)
	my $done = 0;
	$done++ if &parseCmdHook("main", $tell_obj);
	$done++ if &parseCmdHook("extra", $tell_obj);
	$message	= $tell_obj;
	$done++ unless (&Modules());

	&VERB("tell: setting old values of who and msgType.",2);
	$who		= $oldwho;
	$msgType	= $oldmtype;

	if ($done) {
	    &msg($who, "told $target about CMD '$tell_obj'");
	} else {
	    &msg($who, "i dunno what is '$tell_obj'.");
	}

	return;
    }

    # success.
    &status("tell: <$who> telling $target about $tell_obj.");
    if ($who ne $target) {
	if ($dont_tell_me) {
	    &msg($who, "told $target about $tell_obj.");
	} else {
	    &msg($who, "told $target about $tell_obj ($result)");
	}

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
    $dns =~ s/^\s+|\s+$//g;

    if (!defined $dns or $dns =~ /^\s*$/ or $dns =~ / /) {
	&help("dns");
	return;
    }

    if ($dns =~ /(\d+\.\d+\.\d+\.\d+)/) {
	$match = $1;
	&status("DNS query by IP address: $match");

	$y = pack('C4', split(/\./, $match));
	$x = (gethostbyaddr($y, &AF_INET));

	if ($x !~ /^\s*$/) {
	    $result = $match." is ".$x unless ($x =~ /^\s*$/);
	} else {
	    $result = "I can't seem to find that address in DNS";
        }

    } else {

	&status("DNS query by name: $dns");
	$x = join('.',unpack('C4',(gethostbyname($dns))[4]));

	if ($x !~ /^\s*$/) {
	    $result = $dns." is ".$x;
	} else {
	    $result = "I can\'t find that machine name";
	}
    }

    &performReply($result);
}

sub countryStats {
    if (exists $cache{countryStats}) {
	&msg($who,"countrystats is already running!");
	return;
    }

    if ($chan eq "") {
	$chan = $_[0];
    }

    if ($chan eq "") {
	&help("countrystats");
	return;
    }

    $conn->who($chan);
    $cache{countryStats}{chan}	= $chan;
    $cache{countryStats}{mtype}	= $msgType;
    $cache{countryStats}{who}	= $who;
    $cache{on_who_Hack}		= 1;
}

sub do_countrystats {
    $chan	= $cache{countryStats}{chan};
    $msgType	= $cache{countryStats}{mtype};
    $who	= $cache{countryStats}{who};

    my $total	= 0;
    my %cstats;
    foreach (keys %{ $cache{nuhInfo} }) {
	my $h = $cache{nuhInfo}{$_}{Host};

	if ($h =~ /^.*\.(\D+)$/) {	# host
	    $cstats{$1}++;
	} else {			# ip
	    $cstats{unresolve}++;
	}
	$total++;
    }
    my %count;
    foreach (keys %cstats) {
	$count{ $cstats{$_} }{$_} = 1;
    }

    my @list;
    foreach (sort {$b <=> $a} keys %count) {
	my $str = join(", ", sort keys %{ $count{$_} });
#	push(@list, "$str ($_)");
	my $perc	= sprintf("%.01f", 100 * $_ / $total);
	$perc		=~ s/\.0+$//;
	push(@list, "$str ($_, $perc %)");
    }

    # todo: move this into a scheduler like nickometer
    $msgType	= "private";
    &pSReply( &formListReply(0, "Country Stats ", @list) );

    delete $cache{countryStats};
    delete $cache{on_who_Hack};
}

###
### amalgamated commands.
###

sub userCommands {
    # conversion: ascii.
    if ($message =~ /^(asci*|chr) (\d+)$/) {
	&DEBUG("ascii/chr called ...");
	return unless (&hasParam("allowConv"));

	&DEBUG("ascii/chr called");

	$arg	= $2;
	$result	= chr($arg);
	$result	= "NULL"	if ($arg == 0);

	&performReply( sprintf("ascii %s is '%s'", $arg, $result) );

	return;
    }

    # conversion: ord.
    if ($message =~ /^ord(\s+(.*))$/) {
	return unless (&hasParam("allowConv"));

	$arg = $2;

	if (!defined $arg or length $arg != 1) {
	    &help("ord");
	    return;
	}

	if (ord($arg) < 32) {
	    $arg = chr(ord($arg) + 64);
	    if ($arg eq chr(64)) {
		$arg = 'NULL';
	    } else {
		$arg = '^'.$arg;
	    }
	}

	&performReply( sprintf("'%s' is ascii %s", $arg, ord $1) );
	return;
    }

    # hex.
    if ($message =~ /^hex(\s+(.*))?$/i) {
	return unless (&hasParam("allowConv"));
	my $arg = $2;

	if (!defined $arg) {
	    &help("hex");
	    return;
	}

	if (length $arg > 80) {
	    &msg($who, "Too long.");
	    return;
	}

	my $retval;
	foreach (split //, $arg) {
	    $retval .= sprintf(" %X", ord($_));
	}

	&pSReply("$arg is$retval");

	return;
    }

    # crypt.
    if ($message =~ /^crypt(\s+(.*))?$/i) {
	my @args	= split /\s+/, $2;

	if (!scalar @args or scalar @args > 2) {
	    &help("crypt");
	    return;
	}

	if (scalar @args == 2) {
	    if (length $args[0] != 2) {
		&msg($who, "invalid format...");
		return;
	    }

	    &pSReply( crypt($args[1], $args[0]) );
	} else {
	    &pSReply( &mkcrypt($args[0]) );
	}

	return;
    }

    # cycle.
    if ($message =~ /^(cycle)(\s+(\S+))?$/i) {
	return unless (&hasFlag("o"));
	my $chan = lc $3;

	if ($chan eq "") {
	    if ($msgType =~ /public/) {
		$chan = $talkchannel;
		&DEBUG("cycle: setting chan to '$chan'.");
	    } else {
		&help("cycle");
		return;
	    }
	}

	if (&validChan($chan) == 0) {
	    &msg($who,"error: invalid channel \002$chan\002");
	    return;
	}

	&msg($chan, "I'm coming back. (courtesy of $who)");
	&part($chan);
###	&ScheduleThis(5, "getNickInUse") if (@_);
	&status("Schedule rejoin in 5secs to $chan by $who.");
	$conn->schedule(5, sub { &joinchan($chan); });

	return;
    }

    # reload.
    if ($message =~ /^reload$/i) {
	return unless (&hasFlag("n"));

	&status("USER reload $who");
	&pSReply("reloading...");
	&reloadAllModules();
	&pSReply("reloaded.");
	return;
    }

    # redir.
    if ($message =~ /^redir(\s+(.*))?/i) {
	return unless (&hasFlag("o"));
	my $factoid = $2;

	if (!defined $factoid) {
	    &help("redir");
	    return;
	}

	my $val  = &getFactInfo($factoid, "factoid_value");
	if (!defined $val or $val eq "") {
	    &msg($who, "error: '$factoid' does not exist.");
	    return;
	}
	&DEBUG("val => '$val'.");
	my @list = &searchTable("factoids", "factoid_key",
					"factoid_value", "^$val\$");

	if (scalar @list == 1) {
	    &msg($who, "hrm... '$factoid' is unique.");
	    return;
	}
	if (scalar @list > 5) {
	    &msg($who, "A bit too many factoids to be redirected, hey?");
	    return;
	}

	my @redir;
	&status("Redirect '$factoid' (". ($#list) .")...");
	for (@list) {
	    my $x = $_;
	    next if (/^\Q$factoid\E$/i);

	    &status("  Redirecting '$_'.");
	    my $was = &getFactoid($_);
	    if ($was =~ /<REPLY> see/i) {
		&status("warn: not redirecting a redirection.");
		next;
	    }

	    &DEBUG("  was '$was'.");
	    push(@redir,$x);
	    &setFactInfo($x, "factoid_value", "<REPLY> see $factoid");
	}
	&status("Done.");

	&msg($who, &formListReply(0, "'$factoid' is redirected to by '", @redir));

	return;
    }

    # rot13 it.
    if ($message =~ /^rot13(\s+(.*))?/i) {
	my $reply = $2;

	if (!defined $reply) {
	    &help("rot13");
	    return;
	}

	$reply =~ y/A-Za-z/N-ZA-Mn-za-m/;
	&pSReply($reply);

	return;
    }

    # cpustats.
    if ($message =~ /^cpustats$/i) {
	if ($^O !~ /linux/) {
	    &ERROR("cpustats: your OS is not supported yet.");
	    return;
	}

	### poor method to get info out of file, please fix.
	open(STAT,"/proc/$$/stat");
	my $line = <STAT>;
	chop $line;
	my @data = split(/ /, $line);
	close STAT;

	# utime(13) + stime(14).
	my $cpu_usage	= sprintf("%.01f", ($data[13]+$data[14]) / 100 );
	# cutime(15) + cstime (16).
	my $cpu_usage2	= sprintf("%.01f", ($data[15]+$data[16]) / 100 );
	my $time	= time() - $^T;
	my $raw_perc	= $cpu_usage*100/$time;
	my $raw_perc2	= $cpu_usage2*100/$time;
	my $perc;
	my $perc2;
	my $total;
	my $ratio;

	if ($raw_perc > 1) {
	    $perc	= sprintf("%.01f", $raw_perc);
	    $perc2	= sprintf("%.01f", $raw_perc2);
	    $total	= sprintf("%.01f", $raw_perc+$raw_perc2);
	} elsif ($raw_perc > 0.1) {
	    $perc	= sprintf("%.02f", $raw_perc);
	    $perc2	= sprintf("%.02f", $raw_perc2);
	    $total	= sprintf("%.02f", $raw_perc+$raw_perc2);
	} else {			# <=0.1
	    $perc	= sprintf("%.03f", $raw_perc);
	    $perc2	= sprintf("%.03f", $raw_perc2);
	    $total	= sprintf("%.03f", $raw_perc+$raw_perc2);
	}
	$ratio	= sprintf("%.01f", 100*$perc/($perc+$perc2) );

	&pSReply("Total CPU usage: \002$cpu_usage\002 s ... ".
		"Total used: \002$total\002 % ".
		"(parent/child ratio: $ratio %)"
	);

	return;
    }

    # ircstats.
    if ($message =~ /^ircstats?$/i) {
	$ircstats{'TotalTime'}	||= 0;
	$ircstats{'OffTime'}	||= 0;

	my $count	= $ircstats{'ConnectCount'};
	my $format_time	= &Time2String(time() - $ircstats{'ConnectTime'});
	my $total_time	= time() - $ircstats{'ConnectTime'} +
				$ircstats{'TotalTime'};
	my $reply;

	my $connectivity = 100 * ($total_time - $ircstats{'OffTime'}) /
				$total_time;
	my $p = sprintf("%.03f", $connectivity);
	$p =~ s/(\.\d*)0+$/$1/;
	if ($p =~ s/\.0$//) {
	    # this should not happen... but why...
	} else {
	    $p =~ s/\.$//
	}

	if ($total_time != (time() - $ircstats{'ConnectTime'}) ) {
	    my $tt_format = &Time2String($total_time);
	    &DEBUG("tt_format => $tt_format");
	}

	### RECONNECT COUNT.
	if ($count == 1) {	# good.
	    $reply = "I'm connected to $ircstats{'Server'} and have been so".
		" for $format_time";
	} else {
	    $reply = "Currently I'm hooked up to $ircstats{'Server'} but only".
		" for $format_time.  ".
		"I had to reconnect \002$count\002 times.".
		"   Connectivity: $p %";
	}

	### REASON.
	my $reason = $ircstats{'DisconnectReason'};
	if (defined $reason) {
	    $reply .= ".  I was last disconnected for '$reason'.";
	}

	&pSReply($reply);
		
	return;
    }

    # status.
    if ($message =~ /^statu?s$/i) {
	my $startString	= scalar(localtime $^T);
	my $upString	= &Time2String(time() - $^T);
	my $count	= &countKeys("factoids");

	$count{'Commands'}	= 0;
	foreach (keys %cmdstats) {
	    $count{'Commands'} += $cmdstats{$_};
	}

	&pSReply(
	"Since $startString, there have been".
	  " \002$count{'Update'}\002 ".
		&fixPlural("modification", $count{'Update'}).
	  " and \002$count{'Question'}\002 ".
		&fixPlural("question",$count{'Question'}).
	  " and \002$count{'Dunno'}\002 ".
		&fixPlural("dunno",$count{'Dunno'}).
	  " and \002$count{'Moron'}\002 ".
		&fixPlural("moron",$count{'Moron'}).
	  " and \002$count{'Commands'}\002 ".
		&fixPlural("command",$count{'Commands'}).
	  ".  I have been awake for $upString this session, and ".
	  "currently reference \002$count\002 factoids.  ".
	  "I'm using about \002$memusage\002 ".
	  "kB of memory."
	);

	# todo: make dbGetColNiceHash().
	my %hash = &dbGetCol("stats", "nick,counter", "type='cmdstats'".
#			" ORDER BY counter DESC LIMIT 3", 1);
			" ORDER BY counter DESC", 1);

	foreach (keys %hash) {
	    my $i = $_;
	    foreach (keys %{ $hash{$i} }) {
		&DEBUG("cmdstats: $hash{$i}{$_} = $_");
	    }
	}
	&DEBUG("end of cmdstats.");

	return;
    }

    # wantNick. xk++
    if ($message =~ /^wantNick$/i) {
	if ($param{'ircNick'} eq $ident) {
	    &msg($who, "I hope you're right. I'll try anyway.");
	}
	&DEBUG("ircNick => $param{'ircNick'}");
	&DEBUG("ident => $ident");

	if (! &IsNickInAnyChan( $param{ircNick} ) ) {
	    my $str = "attempting to change nick to $param{'ircNick'}";
	    &status($str);
	    &msg($who, $str);
	    &nick($param{'ircNick'});
	} else {
	    &msg($who, "hrm.. I shouldn't do it (BUG?) but doing it anyway!");
	    &DEBUG("wN: nick is somewhere... should try later.");
	    &nick($param{'ircNick'});
	}

	return;
    }

    return "CONTINUE";
}

1;
