#
#   Misc.pl: Miscellaneous stuff.
#    Author: dms
#   Version: 20000124
#      NOTE: Based on code by Kevin Lenzo & Patrick Cole  (c) 1997
#

if (&IsParam("useStrict")) { use strict; }

sub help {
    my $topic = shift;
    my $file  = $bot_data_dir."/blootbot.help";
    my %help  = ();

    # crude hack for pSReply() to work as expected.
    $msgType = "private" if ($msgType eq "public");

    if (!open(FILE, $file)) {
	&ERROR("FAILED loadHelp ($file): $!");
	return;
    }

    while (defined(my $help = <FILE>)) {
	$help =~ s/^[\# ].*//;
	chomp $help;
	next unless $help;
	my ($key, $val) = split(/:/, $help, 2);

	$val =~ s/^\s+//;
	$val =~ s/^D:/\002   Desc\002:/;
	$val =~ s/^E:/\002Example\002:/;
	$val =~ s/^N:/\002   NOTE\002:/;
	$val =~ s/^U:/\002  Usage\002:/;
	$val =~ s/##/$key/;
	$val =~ s/__/\037/g;
	$val =~ s/==/        /;

	$help{$key}  = ""		 if (!exists $help{$key});
	$help{$key} .= $val."\n";
    }
    close FILE;

    if (!defined $topic or $topic eq "") {
	&msg($who, $help{'main'});

	my $i = 0;
	my @array;
	my $count = scalar(keys %help);
	my $reply;
	foreach (sort keys %help) {
	    push(@array,$_);
	    $reply = scalar(@array) ." topics: ".
			join("\002,\002 ", @array);
	    $i++;

	    if (length $reply > 400 or $count == $i) {
		&msg($who,$reply);
		undef @array;
	    }
	}

	return '';
    }

    $topic = &fixString(lc $topic);

    if (exists $help{$topic}) {
	foreach (split /\n/, $help{$topic}) {
	    &performStrictReply($_);
	}
    } else {
	&pSReply("no help on $topic.  Use 'help' without arguments.");
    }

    return '';
}

sub getPath {
    my ($pathnfile) = @_;

    ### TODO: gotta hate an if statement.
    if ($pathnfile =~ /(.*)\/(.*?)$/) {
	return $1;
    } else {
	return ".";
    }
}

sub timeget {
    if ($no_timehires) {	# fallback.
	return time();
    } else {			# the real thing.
	return [gettimeofday()];
    }
}    

sub timedelta {
    my($start_time) = shift;

    if ($no_timehires) {	# fallback.
	return time() - $start_time;
    } else {			# the real thing.
	return tv_interval ($start_time);
    }
}

###
### FORM Functions.
###

###
# Usage; &formListReply($rand, $prefix, @list);
sub formListReply {
    my($rand, $prefix, @list) = @_;
    my $total	= scalar @list;
    my $maxshow = $param{'maxListReplyCount'}  || 10;
    my $maxlen	= $param{'maxListReplyLength'} || 400;
    my $reply;

    # no results.
    return $prefix ."returned no results." unless ($total);

    # random.
    if ($rand) {
	my @rand;
	foreach (&makeRandom($total)) {
	    push(@rand, $list[$_]);
	    last if (scalar @rand == $maxshow);
	}
	@list = @rand;
    } elsif ($total > $maxshow) {
	&status("formListReply: truncating list.");

	@list = @list[0..$maxshow-1];
    }

    # form the reply.
    while () {
	$reply  = $prefix ."(\002". scalar(@list). "\002 shown";
	$reply .= "; \002$total\002 total" if ($total != scalar @list);
	$reply .= "): ". join(" \002;;\002 ",@list) .".";

	last if (length($reply) < $maxlen and scalar(@list) <= $maxshow);
	last if (scalar(@list) == 1);

	pop @list;
    }

    return $reply;
}

### Intelligence joining of arrays.
# Usage: &IJoin(@array);
sub IJoin {
    if (!scalar @_) {
	return "NULL";
    } elsif (scalar @_ == 1) {
	return $_[0];
    } else {
	return join(', ',@{_}[0..$#_-1]) . " and $_[$#_]";
    }
}

#####
# Usage: &Time2String(seconds);
sub Time2String {
    my $time = shift;
    my $retval;

    return("NULL s") if (!defined $time or $time !~ /\d+/);

    my $prefix = "";
    if ($time < 0) {
	$time	= - $time;
	$prefix = "- ";
    }

    my $s = int($time) % 60;
    my $m = int($time / 60) % 60;
    my $h = int($time / 3600) % 24;
    my $d = int($time / 86400);

    my @data;
    push(@data, sprintf("\002%d\002d", $d)) if ($d != 0);
    push(@data, sprintf("\002%d\002h", $h)) if ($h != 0);
    push(@data, sprintf("\002%d\002m", $m)) if ($m != 0);
    push(@data, sprintf("\002%d\002s", $s)) if ($s != 0 or !@data);

    return $prefix.join(' ', @data);
}

###
### FIX Functions.
###

# Usage: &fixFileList(@files);
sub fixFileList {
    my @files = @_;
    my %files;

    # generate a hash list.
    foreach (@files) {
	if (/^(.*\/)(.*?)$/) {
	    $files{$1}{$2} = 1;
	}
    }
    @files = ();	# reuse the array.

    # sort the hash list appropriately.
    foreach (sort keys %files) {
	my $file = $_;
	my @keys = sort keys %{ $files{$file} };
	my $i	 = scalar(@keys);

	if (scalar @keys > 3) {
	    pop @keys while (scalar @keys > 3);
	    push(@keys, "...");
	}

	if ($i > 1) {
	    $file .= "\002{\002". join("\002|\002", @keys) ."\002}\002";
	} else {
	    $file .= $keys[0];
	}

	push(@files,$file);
    }

    return @files;
}

# Usage: &fixString($str);
sub fixString {
    my ($str, $level) = @_;
    if (!defined $str) {
	&WARN("fixString: str == NULL.");
	return '';
    }

    for ($str) {
	s/^\s+//;		# remove start whitespaces.
	s/\s+$//;		# remove end whitespaces.
	s/\s+/ /g;		# remove excessive whitespaces.

	next unless (defined $level);
	if (s/[\cA-\c_]//ig) {		# remove control characters.
	    &DEBUG("stripped control chars");
	}
    }

    return $str;
}

# Usage: &fixPlural($str,$int);
sub fixPlural {
    my ($str,$int) = @_;

    if (!defined $str) {
	&WARN("fixPlural: str == NULL.");
	return;
    }

    if (!defined $int or $int =~ /^\D+$/) {
	&WARN("fixPlural: int != defined or int");
	return $str;
    }

    if ($str eq "has") {
	$str = "have"	if ($int > 1);
    } elsif ($str eq "is") {
	$str = "are"	if ($int > 1);
    } elsif ($str eq "was") {
	$str = "were"	if ($int > 1);
    } elsif ($str eq "this") {
	$str = "these"	if ($int > 1);
    } elsif ($str =~ /y$/) {
	if ($int > 1) {
	    if ($str =~ /ey$/) {
		$str .= "s";	# eg: "money" => "moneys".
	    } else {
		$str =~ s/y$/ies/;
	    }
	}
    } else {
	$str .= "s"	if ($int != 1);
    }

    return $str;
}

##########
### get commands.
###

sub getRandomLineFromFile {
    my($file) = @_;

    if (! -f $file) {
	&WARN("gRLfF: file '$file' does not exist.");
	return;
    }

    if (open(IN,$file)) {
	my @lines = <IN>;

	if (!scalar @lines) {
	    &ERROR("GRLF: nothing loaded?");
	    return;
	}

	while (my $line = &getRandom(@lines)) {
	    chop $line;

	    next if ($line =~ /^\#/);
	    next if ($line =~ /^\s*$/);

	    return $line;
	}
    } else {
	&WARN("gRLfF: could not open file '$file'.");
	return;
    }
}

sub getLineFromFile {
    my($file,$lineno) = @_;

    if (! -f $file) {
	&ERROR("getLineFromFile: file '$file' does not exist.");
	return 0;
    }

    if (open(IN,$file)) {
	my @lines = <IN>;
	close IN;

	if ($lineno > scalar @lines) {
	    &ERROR("getLineFromFile: lineno exceeds line count from file.");
	    return 0;
	}

	my $line = $lines[$lineno-1];
	chop $line;
	return $line;
    } else {
	&ERROR("getLineFromFile: could not open file '$file'.");
	return 0;
    }
}

# Usage: &getRandom(@array);
sub getRandom {
    my @array = @_;

    srand();
    return $array[int(rand(scalar @array))];
}

# Usage: &getRandomInt("30-60");
sub getRandomInt {
    my $str = $_[0];

    if (!defined $str) {
	&WARN("gRI: str == NULL.");
	return;
    }

    srand();

    if ($str =~ /^(\d+(\.\d+)?)$/) {
	my $i = $1;
	my $fuzzy = int(rand 5);
	if ($i < 10) {
	    return $i*60;
	}
	if (rand > 0.5) {
	    return ($i - $fuzzy)*60;
	} else {
	    return ($i + $fuzzy)*60;
	}
    } elsif ($str =~ /^(\d+)-(\d+)$/) {
	return ($2 - $1)*int(rand $1)*60;
    } else {
	return $str;	# hope we're safe.
    }

    &ERROR("getRandomInt: invalid arg '$str'.");
    return 1800;
}

##########
### Is commands.
###

sub iseq {
    my ($left,$right) = @_;
    return 0 unless defined $right;
    return 0 unless defined $left;
    return 1 if ($left =~ /^\Q$right$/i);
}

sub isne {
    my $retval = &iseq(@_);
    return 1 unless ($retval);
    return 0;
}

# Usage: &IsHostMatch($nuh);
sub IsHostMatch {
    my ($thisnuh) = @_;
    my (%this,%local);

    if ($nuh =~ /^(\S+)!(\S+)@(\S+)/) {
	$local{'nick'} = lc $1;
	$local{'user'} = lc $2;
	$local{'host'} = &makeHostMask(lc $3);
    }

    if ($thisnuh =~ /^(\S+)!(\S+)@(\S+)/) {
	$this{'nick'} = lc $1;
	$this{'user'} = lc $2;
	$this{'host'} = &makeHostMask(lc $3);
    } else {
	&WARN("IHM: thisnuh is invalid '$thisnuh'.");
	return 1 if ($thisnuh eq "");
	return 0;
    }

    # auth if 1) user and host match 2) user and nick match.
    # this may change in the future.

    if ($this{'user'} =~ /^\Q$local{'user'}\E$/i) {
	return 2 if ($this{'host'} eq $local{'host'});
	return 1 if ($this{'nick'} eq $local{'nick'});
    }
    return 0;
}

####
# Usage: &isStale($file, $age);
sub isStale {
    my ($file, $age) = @_;

    if (!defined $age) {
	&WARN("isStale: age == NULL.");
	return 1;
    }

    if (!defined $file) {
	&WARN("isStale: file == NULL.");
	return 1;
    }

    &DEBUG("!exist $file") if (! -f $file);

    return 1 unless ( -f $file);
    if ($file =~ /idx/) {
	my $age2 = time() - (stat($file))[9];
	&VERB("stale: $age2. (". &Time2String($age2) .")",2);
    }
    $age *= 60*60*24 if ($age >= 0 and $age < 30);

    return 1 if (time() - (stat($file))[9] > $age);
    return 0;
}

##########
### make commands.
###

# Usage: &makeHostMask($host);
sub makeHostMask {
    my ($host)	= @_;
    my $nu	= "";

    if ($host =~ s/^(\S+!\S+\@)//) {
	&DEBUG("mHM: detected nick!user\@ for host arg; fixing");
	$nu = $1;
    }

    if ($host =~ /^$mask{ip}$/) {
	return $nu."$1.$2.$3.*";
    }

    my @array = split(/\./, $host);
    return $nu.$host if (scalar @array <= 3);
    return $nu."*.".join('.',@{array}[1..$#array]);
}

# Usage: &makeRandom(int);
sub makeRandom {
    my ($max) = @_;
    my @retval;
    my %done;

    if ($max =~ /^\D+$/) {
	&ERROR("makeRandom: arg ($max) is not integer.");
	return 0;
    }

    if ($max < 1) {
	&ERROR("makeRandom: arg ($max) is not positive.");
	return 0;
    }

    srand();
    while (scalar keys %done < $max) {
	my $rand = int(rand $max);
	next if (exists $done{$rand});

	push(@retval,$rand);
	$done{$rand} = 1;
    }

    return @retval;
}

sub checkMsgType {
    my ($reply) = @_;
    return unless (&IsParam("minLengthBeforePrivate"));
    return if ($force_public_reply);

    if (length $reply > $param{'minLengthBeforePrivate'}) {
	&status("Reply: len reply > minLBP ($param{'minLengthBeforePrivate'}); msgType now private.");
	$msgType = 'private';
    }
}

###
### Valid.
###

# Usage: &validExec($string);
sub validExec {
    my ($str) = @_;

    if ($str =~ /[\'\"\|]/) {	# invalid.
	return 0;
    } else {			# valid.
	return 1;
    }
}

# Usage: &hasProfanity($string);
sub hasProfanity {
    my ($string) = @_;
    my $profanity = 1;

    for (lc $string) {
	/fuck/ and last;
	/dick|dildo/ and last;
	/shit|turd|crap/ and last;
	/pussy|[ck]unt/ and last;
	/wh[0o]re|bitch|slut/ and last;

	$profanity = 0;
    }

    return $profanity;
}

sub hasParam {
    my ($param) = @_;

    if (&IsChanConf($param) or &IsParam($param)) {
	return 1;
    } else {
	### TODO: specific reason why it failed.
	&msg($who, "unfortunately, \002$param\002 is disabled in my configuration") unless ($addrchar);
	return 0;
    }
}

sub Forker {
    my ($label, $code) = @_;
    my $pid;

    &shmFlush();
    &VERB("double fork detected; not forking.",2) if ($$ != $bot_pid);

    if (&IsParam("forking") and $$ == $bot_pid) {
	return unless &addForked($label);

	$SIG{CHLD} = 'IGNORE';
	$pid = eval { fork() };
	return if $pid;		# parent does nothing

	select(undef, undef, undef, 0.2);
#	&status("fork starting for '$label', PID == $$.");
	&status("--- fork starting for '$label', PID == $$ ---");
	&shmWrite($shm,"SET FORKPID $label $$");

	sleep 1;
    }

    ### TODO: use AUTOLOAD
    ### very lame hack.
    if ($label !~ /-/ and !&loadMyModule($myModules{$label})) {
	&DEBUG("Forker: failed?");
	&delForked($label);
    }

    if (defined $code) {
	$code->();			# weird, hey?
    } else {
	&WARN("Forker: code not defined!");
    }

    &delForked($label);
}

sub closePID {
    return 1 unless (exists $file{PID});
    return 1 unless ( -f $file{PID});
    return 1 if (unlink $file{PID});
    return 0 if ( -f $file{PID});
}

sub mkcrypt {
    my($str) = @_;
    my $salt = join '',('.','/',0..9,'A'..'Z','a'..'z')[rand 64, rand 64];

    return crypt($str, $salt);
}

sub closeStats {
    return unless (&getChanConfList("ircTextCounters"));

    foreach (keys %cmdstats) {
	my $type	= $_;
	my $i	= &dbGet("stats", "counter", "nick=".&dbQuote($type).
			" AND type='cmdstats'");
	my $z	= 0;
	$z++ unless ($i);

	$i	+= $cmdstats{$type};

	my %hash = (
		nick => $type,
		type => "cmdstats",
		counter => $i
	);		
	$hash{time} = time() if ($z);

	&dbReplace("stats", "nick", %hash);
    }
}

1;
