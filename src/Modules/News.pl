#
# News.pl: Advanced news management
#   Author: dms
#  Version: v0.3 (20014012)
#  Created: 20010326
#    Notes: Testing done by greycat, kudos!
#
### structure:
# news{ channel }{ string } { item }
# newsuser{ channel }{ user } = time()
### where item is:
#	Time	- when it was added (used for sorting)
#	Author	- Who by.
#	Expire	- Time to expire.
#	Text	- Actual text.
###

package News;

sub Parse {
    my($what)	= @_;
    $chan	= undef;

    if (!keys %::news) {
	if (!exists $::cache{newsFirst}) {
	    &::DEBUG("looks like we enabled news option just then; loading up news file just in case.");
	    $::cache{newsFirst} = 1;
	}

	&readNews();
    }

    if ($::msgType ne "private") {
	$chan = $::chan;
    }

    if (defined $what and $what =~ s/^($::mask{chan})\s*//) {
	# todo: check if the channel exists aswell.
	$chan	= lc $1;

	if (!&::IsNickInChan($::who, $chan)) {
	    &::notice($::who, "sorry but you're not on $chan.");
	    return;
	}
    }

    if (!defined $chan) {
	my @chans = &::getNickInChans($::who);

	if (scalar @chans > 1) {
	    &::notice($::who, "error: I dunno which channel you are referring to since you're on more than one. Try 'news #chan ...' instead");
	    return;
	}

	if (scalar @chans == 0) {
	    &::notice($::who, "error: I couldn't find you on any chan. This must be a bug!");
	    return;
	}

	$chan	= $chans[0];
	&::VERB("Guessed $::who being on chan $chan",2);
	$::chan	= $chan;	# hack for IsChanConf().
    }

    if (!defined $what or $what =~ /^\s*$/) {
	&list();
	return;
    }

    if ($what =~ /^add(\s+(.*))?$/i) {
	&add($2);

    } elsif ($what =~ /^del(\s+(.*))?$/i) {
	&del($2);

    } elsif ($what =~ /^mod(\s+(.*))?$/i) {
	&mod($2);

    } elsif ($what =~ /^set(\s+(.*))?$/i) {
	&set($2);

    } elsif ($what =~ /^(\d+)$/i) {
	&::VERB("News: read shortcut called.",2);
	&read($1);

    } elsif ($what =~ /^read(\s+(.*))?$/i) {
	&read($2);

    } elsif ($what =~ /^(latest|new)(\s+(.*))?$/i) {
	&latest($3 || $chan, 1);
#	$::cmdstats{'News latest'}++;

    } elsif ($what =~ /^stats?$/i) {
	&stats();

    } elsif ($what =~ /^list$/i) {
	&list();

    } elsif ($what =~ /^(expire|text|desc)(\s+(.*))?$/i) {
	# shortcut/link.
	# nice hack.
	my($arg1,$arg2) = split(/\s+/, $3, 2);
	&set("$arg1 $1 $arg2");

    } elsif ($what =~ /^help(\s+(.*))?$/i) {
	&::help("news$1");

    } elsif ($what =~ /^newsflush$/i) {
	&::msg($::who, "newsflush called... check out the logs!");
	&::newsFlush();

    } elsif ($what =~ /^(un)?notify$/i) {
	my $state = ($1) ? 0 : 1;

	# todo: don't notify even if "news" is called.
	if (!&::IsChanConf("newsNotifyAll")) {
	    &::DEBUG("chan => $chan, ::chan => $::chan.");
	    &::notice($::who, "not available for this channel or disabled altogether.");
	    return;
	}

	my $t = $::newsuser{$chan}{$::who};
	if ($state) {	# state = 1
	    if (defined $t and ($t == 0 or $t == -1)) {
		&::notice($::who, "enabled notify.");
		delete $::newsuser{$chan}{$::who};
		return;
	    }
	    &::notice($::who, "already enabled.");

	} else {		# state = 0
	    my $x = $::newsuser{$chan}{$::who};
	    if (defined $x and ($x == 0 or $x == -1)) {
		&::notice($::who, "notify already disabled");
		return;
	    }
	    $::newsuser{$chan}{$::who} = -1;
	    &::notice($::who, "notify is now disabled.");
	}

    } else {
	&::DEBUG("could not parse '$what'");
	&::notice($::who, "unknown command: $what");
    }
}

sub readNews {
    my $file = "$::bot_base_dir/blootbot-news.txt";
    if (! -f $file or -z $file) {
	return;
    }

    if (fileno NEWS) {
	&::DEBUG("readNews: fileno exists, should never happen.");
	return;
    }

    my($item,$chan);
    my($ci,$cu) = (0,0);

    open(NEWS, $file);
    while (<NEWS>) {
	chop;

	# todo: allow commands.

	if (/^[\s\t]+(\S+):[\s\t]+(.*)$/) {
	    if (!defined $item) {
		&::DEBUG("!defined item, never happen!");
		next;
	    }

	    $::news{$chan}{$item}{$1} = $2;
	    next;
	}

	# U <chan> <nick> <time>
	if (/^U\s+(\S+)\s+(\S+)\s+(\d+)$/) {
	    $::newsuser{$1}{$2} = $3;
	    $cu++;
	    next;
	}

	if (/^(\S+)[\s\t]+(.*)$/) {
	    $chan = $1;
	    $item = $2;
	    $ci++;
	}
    }
    close NEWS;

    my $cn = scalar(keys %::news);
    &::status("News: Read ".
	$ci. &::fixPlural(" item", $ci). " for ".
	$cn. &::fixPlural(" chan", $cn). ", ".
	$cu. &::fixPlural(" user", $cu), " cache"
    ) if ($ci or $cn or $cu);
}

sub writeNews {
    if (!scalar keys %::news and !scalar keys %::newsuser) {
	&::VERB("wN: nothing to write.",2);
	return;
    }

    my $file = "$::bot_base_dir/blootbot-news.txt";

    if (fileno NEWS) {
	&::ERROR("fileno NEWS exists, should never happen.");
	return;
    }

    # todo: add commands to output file.
    my $c = 0;
    my($cc,$ci,$cu) = (0,0,0);

    open(NEWS, ">$file");
    foreach $chan (sort keys %::news) {
	$c = scalar keys %{ $::news{$chan} };
	next unless ($c);
	$cc++;

	foreach $item (sort keys %{ $::news{$chan} }) {
	    $c = scalar keys %{ $::news{$chan}{$item} };
	    next unless ($c);
	    $ci++;

	    print NEWS "$chan $item\n";
	    foreach $what (sort keys %{ $::news{$chan}{$item} }) {
		print NEWS "    $what: $::news{$chan}{$item}{$what}\n";
	    }
	    print NEWS "\n";
	}
    }

    # todo: show how many users we wrote down.
    if (&::getChanConfList("newsKeepRead")) {
	# old users are removed in newsFlush(), perhaps it should be
	# done here.

	foreach $chan (sort keys %::newsuser) {

	    foreach (sort keys %{ $::newsuser{$chan} }) {
		print NEWS "U $chan $_ $::newsuser{$chan}{$_}\n";
		$cu++;
	    }
	}
    }

    close NEWS;

    &::status("News: Wrote $ci items for $cc chans, $cu user cache.");
}

sub add {
    my($str) = @_;

    if (!defined $chan or !defined $str or $str =~ /^\s*$/) {
	&::help("news add");
	return;
    }

    if (length $str > 64) {
	&::notice($::who, "That's not really an item (>64chars)");
	return;
    }

    if (exists $::news{$chan}{$str}{Time}) {
	&::notice($::who, "'$str' for $chan already exists!");
	return;
    }

    $::news{$chan}{$str}{Time}	= time();
    my $expire = &::getChanConfDefault("newsDefaultExpire",7);
    $::news{$chan}{$str}{Expire}	= time() + $expire*60*60*24;
    $::news{$chan}{$str}{Author}	= $::who;

    my $agestr	= &::Time2String($::news{$chan}{$str}{Expire} - time() );
    my $item	= &newsS2N($str);
    &::notice($::who, "Added '\037$str\037' at [".localtime(time).
		"] by \002$::who\002 for item #\002$item\002.");
    &::notice($::who, "Now do 'news text $item <your_description>'");
    &::notice($::who, "This item will expire at \002".
	localtime($::news{$chan}{$str}{Expire})."\002 [$agestr from now] "
    );

    &writeNews();
}

sub del {
    my($what)	= @_;
    my $item	= 0;

    if (!defined $what) {
	&::help("news del");
	return;
    }

    if ($what =~ /^\d+$/) {
	my $count = scalar keys %{ $::news{$chan} };
	if (!$count) {
	    &::notice($::who, "No news for $chan.");
	    return;
	}

	if ($what > $count or $what < 0) {
	    &::notice($::who, "$what is out of range (max $count)");
	    return;
	}

	$item	= &getNewsItem($what);
	$what	= $item;		# hack hack hack.

    } else {
	$_	= &getNewsItem($what);	# hack hack hack.
	$what	= $_ if (defined $_);

	if (!exists $::news{$chan}{$what}) {
	    my @found;
	    foreach (keys %{ $::news{$chan} }) {
		next unless (/\Q$what\E/);
		push(@found, $_);
	    }

	    if (!scalar @found) {
		&::notice($::who, "could not find $what.");
		return;
	    }

	    if (scalar @found > 1) {
		&::notice($::who, "too many matches for $what.");
		return;
	    }

	    $what	= $found[0];
	    &::DEBUG("del: str: guessed what => $what");
	}
    }

    if (exists $::news{$chan}{$what}) {
	my $auth = 0;
	$auth++ if ($::who eq $::news{$chan}{$what}{Author});
	$auth++ if (&::IsFlag("o"));

	if (!$auth) {
	    # todo: show when it'll expire.
	    &::notice($::who, "Sorry, you cannot remove items; just let them expire on their own.");
	    return;
	}

	&::notice($::who, "ok, deleted '$what' from \002$chan\002...");
	delete $::news{$chan}{$what};
    } else {
	&::notice($::who, "error: not found $what in news for $chan.");
    }
}

sub list {
    if (!scalar keys %{ $::news{$chan} }) {
	&::notice($::who, "No News for \002$chan\002.");
	return;
    }

    if (&::IsChanConf("newsKeepRead")) {
	my $x = $::newsuser{$chan}{$::who};

	if (defined $x and ($x == 0 or $x == -1)) {
	    &::DEBUG("not updating time for $::who.");
	} else {
	    if (!scalar keys %{ $::news{$chan} }) {
		&DEBUG("news: should not add $chan/$::who to cache!");
	    }

	    $::newsuser{$chan}{$::who} = time();
	}
    }

    my $count = scalar keys %{ $::news{$chan} };
    &::notice($::who, "|==== News for \002$chan\002: ($count items)");
    my $newest	= 0;
    foreach (keys %{ $::news{$chan} }) {
	my $t	= $::news{$chan}{$_}{Time};
	$newest = $t if ($t > $newest);
    }
    my $timestr = &::Time2String(time() - $newest);
    &::notice($::who, "|= Last updated $timestr ago.");
    &::notice($::who, " \037Num\037 \037Item ".(" "x40)." \037");

    my $i = 1;
    foreach ( &getNewsAll() ) {
	my $subtopic	= $_;
	my $setby	= $::news{$chan}{$subtopic}{Author};

	if (!defined $subtopic) {
	    &::DEBUG("warn: subtopic == undef.");
	    next;
	}

	# todo: show request stats aswell.
	&::notice($::who, sprintf("\002[\002%2d\002]\002 %s",
				$i, $subtopic));
	$i++;
    }

    &::notice($::who, "|= End of News.");
    &::notice($::who, "use 'news read <#>' or 'news read <keyword>'");
}

sub read {
    my($str) = @_;

    if (!defined $chan or !defined $str or $str =~ /^\s*$/) {
	&::help("news read");
	return;
    }

    if (!scalar keys %{ $::news{$chan} }) {
	&::notice($::who, "No News for \002$chan\002.");
	return;
    }

    my $item	= &getNewsItem($str);
    if (!defined $item or !scalar keys %{ $::news{$chan}{$item} }) {
	&::notice($::who, "No news item called '$str'");
	return;
    }

    if (!exists $::news{$chan}{$item}{Text}) {
	&::notice($::who, "Someone forgot to add info to this news item");
	return;
    }

    my $t	= localtime( $::news{$chan}{$item}{Time} );
    my $a	= $::news{$chan}{$item}{Author};
    my $text	= $::news{$chan}{$item}{Text};
    my $num	= &newsS2N($item);
    my $rwho	= $::news{$chan}{$item}{Request_By} || $::who;
    my $rcount	= $::news{$chan}{$item}{Request_Count} || 0;

    if (length $text < $::param{maxKeySize}) {
	&::VERB("NEWS: Possible news->factoid redirection.",2);
	my $f	= &::getFactoid($text);

	if (defined $f) {
	    &::VERB("NEWS: ok, $text is factoid redirection.",2);
	    $f =~ s/^<REPLY>\s*//i;	# anything else?
	    $text = $f;
	}
    }

    $_ = $::news{$chan}{$item}{'Expire'};
    my $e;
    if ($_) {
	$e = sprintf("\037%s\037  [%s from now]",
		scalar(localtime($_)),
		&::Time2String($_ - time())
	);
    }

    &::notice($::who, "+- News \002$chan\002 #$num: $item");
    &::notice($::who, "| Added by $a at \037$t\037");
    &::notice($::who, "| Expire: $e") if (defined $e);
    &::notice($::who, $text);
    &::notice($::who, "| Requested \002$rcount\002 times, last by \002$rwho\002") if ($rcount and $rwho);

    $::news{$chan}{$item}{'Request_By'}   = $::who;
    $::news{$chan}{$item}{'Request_Time'} = time();
    $::news{$chan}{$item}{'Request_Count'}++;
}

sub mod {
    my($item, $str) = split /\s+/, $_[0], 2;

    if (!defined $item or $item eq "" or $str =~ /^\s*$/) {
	&::help("news mod");
	return;
    }

    my $news = &getNewsItem($item);

    if (!defined $news) {
	&::DEBUG("error: mod: news == undefined.");
	return;
    }
    my $nnews = $::news{$chan}{$news}{Text};
    my $mod_news  = $news;
    my $mod_nnews = $nnews;

    # SAR patch. mu++
    if ($str =~ m|^\s*s([/,#\|])(.+?)\1(.*?)\1([a-z]*);?\s*$|) {
	my ($delim, $op, $np, $flags) = ($1,$2,$3,$4);

	if ($flags !~ /^(g)?$/) {
	    &::notice($::who, "error: Invalid flags to regex.");
	    return;
	}

	### TODO: use m### to make code safe!
	# todo: make code safer.
	my $done = 0;
	# todo: use eval to deal with flags easily.
	if ($flags eq "") {
	    $done++ if (!$done and $mod_news  =~ s/\Q$op\E/$np/);
	    $done++ if (!$done and $mod_nnews =~ s/\Q$op\E/$np/);
        } elsif ($flags eq "g") {
	    $done++ if ($mod_news  =~ s/\Q$op\E/$np/g);
	    $done++ if ($mod_nnews =~ s/\Q$op\E/$np/g);
	}

	if (!$done) {
	    &::notice($::who, "warning: regex not found in news.");
	    return;
	}

	if ($mod_news ne $news) { # news item.
	    if (exists $::news{$chan}{$mod_news}) {
		&::notice($::who, "item '$mod_news' already exists.");
		return;
	    }

	    &::notice($::who, "Moving item '$news' to '$mod_news' with SAR s/$op/$np/.");
	    foreach (keys %{ $::news{$chan}{$news} }) {
		$::news{$chan}{$mod_news}{$_} = $::news{$chan}{$news}{$_};
		delete $::news{$chan}{$news}{$_};
	    }
	    # needed?
	    delete $::news{$chan}{$news};
	}

	if ($mod_nnews ne $nnews) { # news Text/Description.
	    &::notice($::who, "Changing text for '$news' SAR s/$op/$np/.");
	    if ($mod_news ne $news) {
		$::news{$chan}{$mod_news}{Text} = $mod_nnews;
	    } else {
		$::news{$chan}{$news}{Text}	= $mod_nnews;
	    }
	}

	return;
    } else {
	&::notice($::who, "error: that regex failed ;(");
	return;
    }

    &::notice($::who, "error: Invalid regex. Try s/1/2/, s#3#4#...");
}

sub set {
    my($args) = @_;
    $args =~ /^(\S+)\s+(\S+)\s+(.*)$/;
    my($item, $what, $value) = ($1,$2,$3);

    &::DEBUG("set called.");

    if ($item eq "") {
	&::help("news set");
	return;
    }

    &::DEBUG("item => '$item'.");
    my $news = &getNewsItem($item);

    if (!defined $news) {
	&::notice($::who, "Could not find item '$item' substring or # in news list.");
	return;
    }

    # list all values for chan.
    if (!defined $what) {
	&::DEBUG("set: 1");
	return;
    }

    my $ok = 0;
    my @elements = ("Expire","Text");
    foreach (@elements) {
	next unless ($what =~ /^$_$/i);
	$what = $_;
	$ok++;
	last;
    }

    if (!$ok) {
	&::notice($::who, "Invalid set.  Try: @elements");
	return;
    }

    # show (read) what.
    if (!defined $value) {
	&::DEBUG("set: 2");
	return;
    }

    if (!exists $::news{$chan}{$news}) {
	&::notice($::who, "news '$news' does not exist");
	return;
    }

    if ($what eq "Expire") {
	# todo: use do_set().

	my $time = 0;
	my $plus = ($value =~ s/^\+//g);
	while ($value =~ s/^(\d+)(\S*)\s*//) {
	    my($int,$unit) = ($1,$2);
	    $time += $int	if ($unit =~ /^s(ecs?)?$/i);
	    $time += $int*60	if ($unit =~ /^m(in(utes?)?)?$/i);
	    $time += $int*60*60 if ($unit =~ /^h(ours?)?$/i);
	    $time += $int*60*60*24 if (!$unit or $unit =~ /^d(ays?)?$/i);
	    $time += $int*60*60*24*7 if ($unit =~ /^w(eeks?)?$/i);
	    $time += $int*60*60*24*30 if ($unit =~ /^mon(th)?$/i);
	}

	if ($value =~ s/^never$//i) {
	    # never.
	    $time = -1;
	} elsif ($plus) {
	    # from now.
	    $time += time();
	} else {
	    # from creation of item.
	    $time += $::news{$chan}{$news}{Time};
	}

	if (!$time or ($value and $value !~ /^never$/i)) {
	    &::DEBUG("set: Expire... need to parse.");
	    return;
	}

	if ($time == -1) {
	    &::notice($::who, "Set never expire for \002$item\002." );
	} elsif ($time < -1) {
	    &::DEBUG("time should never be negative ($time).");
	    return;
	} else {
	    &::notice($::who, "Set expire for \002$item\002, to ".
		localtime($time) ." [".&::Time2String($time - time())."]" );

	    if (time() > $time) {
		&::DEBUG("hrm... time() > $time, should expire.");
	    }
	}


	$::news{$chan}{$news}{Expire} = $time;

	return;
    }

    my $auth = 0;
    &::DEBUG("who => '$::who'");
    my $author = $::news{$chan}{$news}{Author};
    $auth++ if ($::who eq $author);
    $auth++ if (&::IsFlag("o"));
    if (!defined $author) {
	&::DEBUG("news{$chan}{$news}{Author} is not defined! auth'd anyway");
	$::news{$chan}{$news}{Author} = $::who;
	$author = $::who;
	$auth++;
    }

    if (!$auth) {
	# todo: show when it'll expire.
	&::notice($::who, "Sorry, you cannot set items. (author $author owns it)");
	return;
    }

    # todo: clean this up.
    my $old = $::news{$chan}{$news}{$what};
    if (defined $old) {
	&::DEBUG("old => $old.");
    }
    $::news{$chan}{$news}{$what} = $value;
    &::notice($::who, "Setting [$chan]/{$news}/<$what> to '$value'.");
}

sub latest {
    my($tchan, $flag) = @_;

    $chan ||= $tchan;	# hack hack hack.

    # todo: if chan = undefined, guess.
    if (!exists $::news{$chan}) {
	&::notice($::who, "invalid chan $chan") if ($flag);
	return;
    }

    my $t = $::newsuser{$chan}{$::who};
    if (defined $t and ($t == 0 or $t == -1)) {
	if ($flag) {
	    &::notice($::who, "if you want to read news, try /msg $::ident news or /msg $::ident news notify");
	} else {
	    &::DEBUG("not displaying any new news for $::who");
	    return;
	}
    }

    my $x = &::IsChanConf("newsNotifyAll");
    if (&::IsChanConf("newsNotifyAll") and !defined $t) {
	$t = 1;
    }

    if (!defined $t) {
	&::DEBUG("something went really wrong.");
	&::DEBUG("chan => $chan, ::chan => $::chan");
	&::notice($::who, "something went really wrong.");
	return;
    }

    my @new;
    foreach (keys %{ $::news{$chan} }) {
	next if (!defined $t);
	next if ($t > $::news{$chan}{$_}{Time});

	# don't list new items if they don't have Text.
	if (!exists $::news{$chan}{$_}{Text}) {
	    if (time() - $::news{$chan}{$_}{Time} > 60*60*24*3) {
		&::DEBUG("deleting news{$chan}{$_} because it was too old and had no text info.");
		delete $::news{$chan}{$_};
	    }

	    next;
	}

	push(@new, $_);
    }

    # !scalar @new, $flag
    if (!scalar @new and $flag) {
	&::notice($::who, "no new news for $chan.");
	return;
    }

    # scalar @new, !$flag
    my $unread	= scalar @new;
    my $total	= scalar keys %{ $::news{$chan} };
    if (!$flag) {
	return unless ($unread);

	my $reply = "There are unread news in $chan ($unread unread, $total total). /msg $::ident news $::chan latest";
	$reply	 .= "  If you don't want further news notification, /msg $::ident news unnotify" if ($unread == $total);
	&::notice($::who, $reply);

	return;
    }

    # scalar @new, $flag
    if (scalar @new) {
	&::notice($::who, "+==== New news for \002$chan\002 ($unread new; $total total):");

	my $t = $::newsuser{$chan}{$::who};
	if (defined $t and $t > 1) {
	    my $timestr = &::Time2String( time() - $t );
	    &::notice($::who, "|= Last time read $timestr ago");
	}

	my @sorted;
	foreach (@new) {
	    my $i   = &newsS2N($_);
	    $sorted[$i] = $_;
	}

	for (my $i=0; $i<=scalar(@sorted); $i++) {
	    my $news = $sorted[$i];
	    next unless (defined $news);

	    my $age = time() - $::news{$chan}{$news}{Time};
	    &::notice($::who, sprintf("\002[\002%2d\002]\002 %s",
		$i, $news) );
#		$i, $_, &::Time2String($age) ) );
	}

	&::notice($::who, "|= to read, do 'news read <#>' or 'news read <keyword>'");

	# lame hack to prevent dupes if we just ignore it.
	my $x = $::newsuser{$chan}{$::who};
	if (defined $x and ($x == 0 or $x == -1)) {
	    &::DEBUG("not updating time for $::who. (2)");
	} else {
	    $::newsuser{$chan}{$::who} = time();
	}
    }
}

###
### helpers...
###

sub getNewsAll {
    my %time;
    foreach (keys %{ $::news{$chan} }) {
	$time{ $::news{$chan}{$_}{Time} } = $_;
    }

    my @items;
    foreach (sort { $a <=> $b } keys %time) {
	push(@items, $time{$_});
    }

    return @items;
}

sub newsS2N {
    my($what)	= @_;
    my $item	= 0;
    my @items;
    my $no;

    my %time;
    foreach (keys %{ $::news{$chan} }) {
	my $t = $::news{$chan}{$_}{Time};

	if (!defined $t or $t !~ /^\d+$/) {
	    &::DEBUG("warn: t is undefined for news{$chan}{$_}{Time}; removing item.");
	    delete $::news{$chan}{$_};
	    next;
	}

	$time{$t} = $_;
    }

    foreach (sort { $a <=> $b } keys %time) {
	$item++;
	return $item if ($time{$_} eq $what);
    }

    &::DEBUG("newsS2N($what): failed...");
}

sub getNewsItem {
    my($what)	= @_;
    my $item	= 0;

    my %time;
    foreach (keys %{ $::news{$chan} }) {
	my $t = $::news{$chan}{$_}{Time};

	if (!defined $t or $t !~ /^\d+$/) {
	    &::DEBUG("warn: t is undefined for news{$chan}{$_}{Time}; removing item.");
	    delete $::news{$chan}{$_};
	    next;
	}

	$time{$t} = $_;
    }

    # number to string resolution.
    if ($what =~ /^\d+$/) {
	foreach (sort { $a <=> $b } keys %time) {
	    $item++;
	    return $time{$_} if ($item == $what);
	}

    } else {
	# partial string to full string resolution
	# in some cases, string->number resolution.

	my @items;
	my $no;
	foreach (sort { $a <=> $b } keys %time) {
	    $item++;
#	    $no = $item if ($time{$_} eq $what);
	    if ($time{$_} eq $what) {
		$no = $item;
		next;
	    }

	    push(@items, $time{$_}) if ($time{$_} =~ /\Q$what\E/i);
	}

	if (defined $no and !@items) {
	    &::DEBUG("string->number resolution: $what->$no.");
	    return $no;
	}

	if (scalar @items > 1) {
	    &::DEBUG("Multiple matches, not guessing.");
	    &::notice($::who, "Multiple matches, not guessing.");
	    return;
	}

	if (@items) {
	    &::DEBUG("gNI: part_string->full_string: $what->$items[0]");
	    return $items[0];
	} else {
	    &::DEBUG("gNI: No match for '$what'");
	    return;
	}
    }

    &::ERROR("getNewsItem: Should not happen (what = $what)");
    return;
}

sub do_set {
    my($what,$value) = @_;

    if (!defined $chan) {
	&::DEBUG("do_set: chan not defined.");
	return;
    }

    if (!defined $what or $what =~ /^\s*$/) {
	&::DEBUG("what $what is not defined.");
	return;
    }
    if (!defined $value or $value =~ /^\s*$/) {
	&::DEBUG("value $value is not defined.");
	return;
    }

    &::DEBUG("do_set: TODO...");
}

sub stats {
    &::DEBUG("News: stats called.");
    &::msg($::who, "check my logs/console.");
    my($i,$j) = (0,0);

    # total request count.
    foreach $chan (keys %::news) {
	foreach (keys %{ $::news{$chan} }) {
	    $i += $::news{$chan}{$_}{Request_Count};
	}
    }
    &::DEBUG("news: stats: total request count => $i");
    $i = 0;

    # total user cached.
    foreach $chan (keys %::newsuser) {
	$i += $::newsuser{$chan}{$_};
    }
    &::DEBUG("news: stats: total user cache => $i");
    $i = 0;

    # average latest time read.
    my $t = time();
    foreach $chan (keys %::newsuser) {
	$i += $t - $::newsuser{$chan}{$_};
	$j++;
    }
    &::DEBUG("news: stats: average latest time read: total time: $i");
    &::DEBUG("... count: $j");
    &::DEBUG("   average: ".sprintf("%.02f", $i/($j||1))." sec/user");
    $i = $j = 0;
}

1;
