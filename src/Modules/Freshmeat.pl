#
# Freshmeat.pl: Frontend to www.freshmeat.net
#       Author: dms
#      Version: v0.7d (20000923)
#      Created: 19990930
#

package Freshmeat;

use strict;

### download compressed version instead?

my %urls = (
	'public'  => 'http://www.freshmeat.net/backend/appindex.txt',
	'private' => 'http://feed.freshmeat.net/appindex/appindex.txt',
);

####
# Usage: &Freshmeat($string);
sub Freshmeat {
    my $sstr	= lc($_[0]);
    my $refresh	= $::param{'freshmeatRefreshInterval'} * 60 * 60;

    my $last_refresh = &::dbGet("freshmeat", "name","_","stable");
    my $renewtable   = 0;

    if (defined $last_refresh) {
	$renewtable++ if (time() - $last_refresh > $refresh);
    } else {
	$renewtable++;
    }
    $renewtable++ if (&::countKeys("freshmeat") < 10);

    if ($renewtable and $$ == $::bot_pid) {
	&::Forker("freshmeat", sub {
		&downloadIndex();
		&Freshmeat($sstr);
	} );
	# both parent/fork runs here, in case the following looks weird.
	return if ($$ == $::bot_pid);
    }

    if (!&showPackage($sstr)) {		# no exact match.
	my $start_time = &::timeget();
	my %hash;

	# search by key/NAME first.
	foreach (&::searchTable("freshmeat", "name","name",$sstr)) {
	    $hash{$_} = 1 unless exists $hash{$_};
	}

	# search by description line.
	foreach (&::searchTable("freshmeat", "name","oneliner", $sstr)) {
	    $hash{$_} = 1 unless exists $hash{$_};
	    last if (scalar keys %hash > 15);
	}

	my @list = keys %hash;
	# search by value, if we have enough room to do it.
	if (scalar @list == 1) {
	    &::status("only one match found; showing full info.");
	    &showPackage($list[0]);
	    return;
	}

	# show how long it took.
	my $delta_time = &::timedelta($start_time);
	&::status(sprintf("freshmeat: %.02f sec to complete query.", $delta_time)) if ($delta_time > 0);

	for (@list) {
	    tr/A-Z/a-z/;
	    s/([\,\;]+)/\037$1\037/g;
	}

	&::performStrictReply( &::formListReply(1, "Freshmeat ", @list) );
    }
}

sub showPackage {
    my ($pkg)	= @_;
    my @fm	= &::dbGet("freshmeat", "name",$pkg,"*");

    if (scalar @fm) {		#1: perfect match of name.
	my $retval;
	$retval  = "$fm[0] \002(\002$fm[11]\002)\002, ";
	$retval .= "section $fm[3], ";
	$retval .= "is $fm[4]. ";
	$retval .= "Stable: \002$fm[1]\002, ";
	$retval .= "Development: \002$fm[2]\002. ";
	$retval .= $fm[5] || $fm[6];		 # fallback to 'download'.
	$retval .= " deb: ".$fm[8] if ($fm[8] ne ""); # 'deb'.
	&::performStrictReply($retval);
	return 1;
    } else {
	return 0;
    }
}

sub randPackage {
    my @fm	= &::randKey("freshmeat","*");

    if (scalar @fm) {		#1: perfect match of name.
	my $retval;
	$retval  = "$fm[0] \002(\002$fm[11]\002)\002, ";
	$retval .= "section $fm[3], ";
	$retval .= "is $fm[4]. ";
	$retval .= "Stable: \002$fm[1]\002, ";
	$retval .= "Development: \002$fm[2]\002. ";
	$retval .= $fm[5] || $fm[6];		 # fallback to 'download'.
	$retval .= " deb: ".$fm[8] if ($fm[8] ne ""); # 'deb'.

	return $retval;
    } else {
	return;
    }
}

sub downloadIndex {
    my $start_time	= &::timeget(); # set the start time.
    my $idx		= "$::param{tempDir}/fm_index.txt";

    &::msg($::who, "Updating freshmeat index... please wait");

    if (&::isStale($idx, 1)) {
	&::status("Freshmeat: fetching data.");
	foreach (keys %urls) {
	    my $retval = &::getURLAsFile($urls{$_}, $idx);
	    next if ($retval =~ /^(403|500)$/);

	    &::DEBUG("FM: last! retval => '$retval'.");
	    last;
	}
    } else {
	&::status("Freshmeat: local file hack.");
    }

    if (! -e $idx) {
	&::msg($::who, "the freshmeat butcher is closed.");
	return;
    }

    if ( -s $idx < 100000) {
	&::DEBUG("FM: index too small?");
	unlink $idx;
	&::msg($::who, "internal error?");
	return;
    }

    if ($idx =~ /bz2$/) {
	open(IN, "bzcat $idx |");
    } elsif ($idx =~ /gz$/) {
	open(IN, "gzcat $idx |");
    } else {
	open(IN, $idx);
    }

    # delete the table before we redo it.
    &::deleteTable("freshmeat");

    ### lets get on with business.
    # set the last refresh time. fixes multiple spawn bug.
    &::dbSet("freshmeat", "name","_","stable",time());

    my $i = 0;
    while (my $line = <IN>) {
	chop $line;
	$i++ if ($line eq "%%");
	last if ($i == 2);
    }

    &::dbRaw("LOCK", "LOCK TABLES freshmeat WRITE");
    my @data;
    my @done;
    while (my $line = <IN>) {
	chop $line;
	if ($line ne "%%") {
	    push(@data,$line);
	    next;
	}

	if ($i % 200 == 0 and $i != 0) {
	    &::DEBUG("FM: unlocking and locking.");
	    &::dbRaw("UNLOCK", "UNLOCK TABLES");
	    ### another lame hack to "prevent" errors.
	    select(undef, undef, undef, 0.2);
	    &::dbRaw("LOCK", "LOCK TABLES freshmeat WRITE");
	}

	if (grep /^\Q$data[0]\E$/, @done) {
	    &::DEBUG("dupe? $data[0]");
	    @data = ();
	    next;
	}

	$i++;
	pop @data;
	$data[1] ||= "none";
	$data[2] ||= "none";
	&::dbSetRow("freshmeat", @data);
	push(@done,$data[0]);
	@data = ();
    }
    close IN;
    &::DEBUG("FM: data ".scalar(@data) );
    &::dbRaw("UNLOCK", "UNLOCK TABLES");

    my $delta_time = &::timedelta($start_time);
    &::status(sprintf("Freshmeat: %.02f sec to complete.", $delta_time)) if ($delta_time > 0);

    my $count = &::countKeys("freshmeat");
    &::status("Freshmeat: $count entries loaded.");
}

sub freshmeatAnnounce {
    my $file = "$::param{tempDir}/fm_recent.txt";
    my @old;

    ### if file exists, lets read it.
    if ( -f $file) {
	open(IN, $file);
	while (<IN>) {
	    chop;
	    push(@old,$_);
	}
	close IN;
    }

    my @array = &::getURL("http://core.freshmeat.net/backend/recentnews.txt");
    my @now;

    while (@array) {
	my($what,$date,$url) = splice(@array,0,3);
	push(@now, $what);
    }

    ### if file does not exist, write new.
    if (! -f $file) {
	open(OUT, ">$file");
	foreach (@now) {
	    print OUT "$_\n";
	}
	close OUT;

	return;
    }

    my @new;
    for(my $i=0; $i<scalar(@old); $i++) {
	last if ($now[$i] eq $old[0]);
	push(@new, $now[$i]);
    }

    if (!scalar @new) {
	&::DEBUG("fA: no new items.");
	return;
    }

    ### output new file.
    open(OUT, ">$file");
    foreach (@now) {
	print OUT "$_\n";
    }
    close OUT;

    return "Freshmeat update: ".join(" \002::\002 ", @new);
}

1;
