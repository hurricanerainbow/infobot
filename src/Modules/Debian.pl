#
#   Debian.pl: Frontend to debian contents and packages files
#      Author: dms
#     Version: v0.8 (20000918)
#     Created: 20000106
#

package Debian;

use strict;

# format: "alias=real".
my $announce	= 0;
my $defaultdist	= "sid";
my $refresh = &::getChanConfDefault("debianRefreshInterval",7)
			* 60 * 60 * 24;

### ... old
#my %dists	= (
#	"sid"		=> "unstable",
#	"woody"		=> "testing",	# new since 20001219.
#	"potato"	=> "stable",
#	"incoming"	=> "incoming",
#);

### new... the right way.
my %dists	= (
	"unstable"	=> "sid",
	"testing"	=> "woody",	# new since 20001219.
	"stable"	=> "potato",
	"incoming"	=> "incoming",
);

my %urlcontents = (
	"debian/Contents-##DIST-i386.gz" =>
		"ftp://ftp.us.debian.org".
		"/debian/dists/##DIST/Contents-i386.gz",
	"debian/Contents-##DIST-i386-non-US.gz" =>
		"ftp://non-us.debian.org".
		"/debian-non-US/dists/##DIST/non-US/Contents-i386.gz",
);

my %urlpackages = (
	"debian/Packages-##DIST-main-i386.gz" =>
		"ftp://ftp.us.debian.org".
		"/debian/dists/##DIST/main/binary-i386/Packages.gz",
	"debian/Packages-##DIST-contrib-i386.gz" =>
		"ftp://ftp.us.debian.org".
		"/debian/dists/##DIST/contrib/binary-i386/Packages.gz",
	"debian/Packages-##DIST-non-free-i386.gz" =>
		"ftp://ftp.us.debian.org".
		"/debian/dists/##DIST/non-free/binary-i386/Packages.gz",

	"debian/Packages-##DIST-non-US-main-i386.gz" =>
		"ftp://non-us.debian.org".
		"/debian-non-US/dists/##DIST/non-US/main/binary-i386/Packages.gz",
	"debian/Packages-##DIST-non-US-contrib-i386.gz" =>
		"ftp://non-us.debian.org".
		"/debian-non-US/dists/##DIST/non-US/contrib/binary-i386/Packages.gz",
	"debian/Packages-##DIST-non-US-non-free-i386.gz" =>
		"ftp://non-us.debian.org".
		"/debian-non-US/dists/##DIST/non-US/non-free/binary-i386/Packages.gz",
);

#####################
### COMMON FUNCTION....
#######################

####
# Usage: &DebianDownload(%hash);
sub DebianDownload {
    my ($dist, %urls)	= @_;
    my $bad	= 0;
    my $good	= 0;

    if (! -d "debian/") {
	&::status("Debian: creating debian dir.");
	mkdir("debian/",0755);
    }

    # fe dists.
    # Download the files.
    my $file;
    foreach $file (keys %urls) {
	my $url = $urls{$file};
	$url  =~ s/##DIST/$dist/g;
	$file =~ s/##DIST/$dist/g;
	my $update = 0;

	if ( -f $file) {
	    my $last_refresh = (stat $file)[9];
	    $update++ if (time() - $last_refresh > $refresh);
	} else {
	    $update++;
	}

	next unless ($update);

	&::DEBUG("announce == $announce.");
	if ($good + $bad == 0 and !$announce) {
	    &::status("Debian: Downloading files for '$dist'.");
	    &::msg($::who, "Updating debian files... please wait.");
	    $announce++;
	}

	if (exists $::debian{$url}) {
	    &::DEBUG("2: ".(time - $::debian{$url})." <= $refresh");
	    next if (time() - $::debian{$url} <= $refresh);
	    &::DEBUG("stale for url $url; updating!");
	}

	if ($url =~ /^ftp:\/\/(.*?)\/(\S+)\/(\S+)$/) {
	    my ($host,$path,$thisfile) = ($1,$2,$3);

### HACK 1
#	    if ($file =~ /Contents-woody-i386-non-US/) {
#		&::DEBUG("Skipping Contents-woody-i386-non-US.");
#		$file =~ s/woody/potato/;
#		$path =~ s/woody/potato/;
#		next;
#	    }

	    if (!&::ftpGet($host,$path,$thisfile,$file)) {
		&::WARN("deb: down: $file == BAD.");
		$bad++;
		next;
	    }

	    if (! -f $file) {
		&::DEBUG("deb: down: ftpGet: !file");
		$bad++;
		next;
	    }

### HACK2
#	    if ($file =~ /Contents-potato-i386-non-US/) {
#		&::DEBUG("hack: using potato's non-US contents for woody.");
#		system("cp debian/Contents-potato-i386-non-US.gz debian/Contents-woody-i386-non-US.gz");
#	    }

	    &::DEBUG("deb: download: good.");
	    $good++;
	} else {
	    &::ERROR("Debian: invalid format of url => ($url).");
	    $bad++;
	    next;
	}
    }

    if ($good) {
	&generateIndex($dist);
	return 1;
    } else {
	return -1 unless ($bad);	# no download.
	&::DEBUG("DD: !good and bad($bad). :(");
	return 0;
    }
}

###########################
# DEBIAN CONTENTS SEARCH FUNCTIONS.
########

####
# Usage: &searchContents($query);
sub searchContents {
    my ($dist, $query)	= &getDistroFromStr($_[0]);
    &::status("Debian: Contents search for '$query' on $dist.");
    my $dccsend	= 0;

    $dccsend++		if ($query =~ s/^dcc\s+//i);

    $query =~ s/\\([\^\$])/$1/g;	# hrm?
    $query =~ s/^\s+|\s+$//g;

    if (!&::validExec($query)) {
	&::msg($::who, "search string looks fuzzy.");
	return;
    }

    if ($dist eq "incoming") {		# nothing yet.
	&::DEBUG("sC: dist = 'incoming'. no contents yet.");
	return;
    } else {
	my %urls = &fixDist($dist, %urlcontents);
	# download contents file.
	&::DEBUG("deb: download 1.");
	if (!&DebianDownload($dist, %urls)) {
	    &::WARN("Debian: could not download files.");
	}
    }

    # start of search.
    my $start_time = &::timeget();

    my $found	= 0;
    my $front	= 0;
    my %contents;
    my $grepRE;
    ### TODO: search properly if /usr/bin/blah is done.
    if ($query =~ s/\$$//) {
	&::DEBUG("search-regex found.");
	$grepRE = "$query\[ \t]";
    } elsif ($query =~ s/^\^//) {
	&::DEBUG("front marker regex found.");
	$front = 1;
	$grepRE = $query;
    } else {
	$grepRE = "$query*\[ \t]";
    }

    # fix up grepRE for "*".
    $grepRE =~ s/\*/.*/g;

    my @files;
    foreach (keys %urlcontents) {
	s/##DIST/$dist/g;

	next unless ( -f $_);
	push(@files,$_);
    }

    if (!scalar @files) {
	&::ERROR("sC: no files?");
	&::msg($::who, "failed.");
	return;
    }

    my $files = join(' ', @files);

    my $regex	= $query;
    $regex	=~ s/\./\\./g;
    $regex	=~ s/\*/\\S*/g;
    $regex	=~ s/\?/./g;

    open(IN,"zegrep -h '$grepRE' $files |");
    while (<IN>) {
	if (/^\.?\/?(.*?)[\t\s]+(\S+)\n$/) {
	    my ($file,$package) = ("/".$1,$2);
	    if ($query =~ /[\/\*\\]/) {
		next unless (eval { $file =~ /$regex/ });
		return unless &checkEval($@);
	    } else {
		my ($basename) = $file =~ /^.*\/(.*)$/;
		next unless (eval { $basename =~ /$regex/ });
		return unless &checkEval($@);
	    }
	    next if ($query !~ /\.\d\.gz/ and $file =~ /\/man\//);
	    next if ($front and eval { $file !~ /^\/$query/ });
	    return unless &checkEval($@);

	    $contents{$package}{$file} = 1;
	    $found++;
	}

	last if ($found > 100);
    }
    close IN;

    my $pkg;

    ### send results with dcc.
    if ($dccsend) {
	if (exists $::dcc{'SEND'}{$::who}) {
	    &::msg($::who, "DCC already active!");
	    return;
	}

	if (!scalar %contents) {
	    &::msg($::who,"search returned no results.");
	    return;
	}

	my $file = "$::param{tempDir}/$::who.txt";
	if (!open(OUT,">$file")) {
	    &::ERROR("Debian: cannot write file for dcc send.");
	    return;
	}

	foreach $pkg (keys %contents) {
	    foreach (keys %{ $contents{$pkg} }) {
		# TODO: correct padding.
		print OUT "$_\t\t\t$pkg\n";
	    }
	}
	close OUT;

	&::shmWrite($::shm, "DCC SEND $::who $file");

	return;
    }

    &::status("Debian: $found contents results found.");

    my @list;
    foreach $pkg (keys %contents) {
	my @tmplist = &::fixFileList(keys %{ $contents{$pkg} });
	my @sublist = sort { length $a <=> length $b } @tmplist;

	pop @sublist while (scalar @sublist > 3);

	$pkg =~ s/\,/\037\,\037/g;	# underline ','.
	push(@list, "(". join(', ',@sublist) .") in $pkg");
    }
    # sort the total list from shortest to longest...
    @list = sort { length $a <=> length $b } @list;

    # show how long it took.
    my $delta_time = &::timedelta($start_time);
    &::status(sprintf("Debian: %.02f sec to complete query.", $delta_time)) if ($delta_time > 0);

    my $prefix = "Debian Search of '$query' ";
    if (scalar @list) {	# @list.
	&::pSReply( &::formListReply(0, $prefix, @list) );
    } else {		# !@list.
	&::DEBUG("ok, !\@list, searching desc for '$query'.");
	my @list = &searchDesc($query);

	if (!scalar @list) {
	    my $prefix = "Debian Package/File/Desc Search of '$query' ";
	    &::pSReply( &::formListReply(0, $prefix, ) );
	} elsif (scalar @list == 1) {	# list = 1.
	    &::DEBUG("list == 1; showing package info of '$list[0]'.");
	    &infoPackages("info", $list[0]);
	} else {				# list > 1.
	    my $prefix = "Debian Desc Search of '$query' ";
	    &::pSReply( &::formListReply(0, $prefix, @list) );
	}
    }
}

####
# Usage: &searchAuthor($query);
sub searchAuthor {
    my ($dist, $query)	= &getDistroFromStr($_[0]);
    &::DEBUG("searchAuthor: dist => '$dist', query => '$query'.");
    $query =~ s/^\s+|\s+$//g;

    # start of search.
    my $start_time = &::timeget();
    &::status("Debian: starting author search.");

    my $files;
    my ($bad,$good) = (0,0);
    my %urls = %urlpackages;

    foreach (keys %urlpackages) {
	s/##DIST/$dist/g;

	if (! -f $_) {
	    $bad++;
	    next;
	}

	$good++;
	$files .= " ".$_;
    }

    &::DEBUG("good = $good, bad = $bad...");

    if ($good == 0 and $bad != 0) {
	my %urls = &fixDist($dist, %urlpackages);
	&::DEBUG("deb: download 2.");
	if (!&DebianDownload($dist, %urls)) {
	    &::ERROR("Debian(sA): could not download files.");
	    return;
	}
    }

    my (%maint, %pkg, $package);
    open(IN,"zegrep -h '^Package|^Maintainer' $files |");
    while (<IN>) {
	if (/^Package: (\S+)$/) {
	    $package = $1;
	} elsif (/^Maintainer: (.*) \<(\S+)\>$/) {
	    my($name,$email) = ($1,$2);
	    if ($package eq "") {
		&::DEBUG("sA: package == NULL.");
		next;
	    }
	    $maint{$name}{$email} = 1;
	    $pkg{$name}{$package} = 1;
	    $package = "";
	} else {
	    &::WARN("invalid line: '$_'.");
	}
    }
    close IN;

    my %hash;
    # TODO: can we use 'map' here?
    foreach (grep /\Q$query\E/i, keys %maint) {
	$hash{$_} = 1;
    }

    # TODO: should we only search email if '@' is used?
    if (scalar keys %hash < 15) {
	my $name;
	foreach $name (keys %maint) {
	    my $email;
	    foreach $email (keys %{ $maint{$name} }) {
		next unless ($email =~ /\Q$query\E/i);
		next if (exists $hash{$name});
		$hash{$name} = 1;
	    }
	}
    }

    my @list = keys %hash;
    if (scalar @list != 1) {
	my $prefix = "Debian Author Search of '$query' ";
	&::pSReply( &::formListReply(0, $prefix, @list) );
	return 1;
    }

    &::DEBUG("showing all packages by '$list[0]'...");

    my @pkg = sort keys %{ $pkg{$list[0]} };

    # show how long it took.
    my $delta_time = &::timedelta($start_time);
    &::status(sprintf("Debian: %.02f sec to complete query.", $delta_time)) if ($delta_time > 0);

    my $email	= join(', ', keys %{ $maint{$list[0]} });
    my $prefix	= "Debian Packages by $list[0] \002<\002$email\002>\002 ";
    &::pSReply( &::formListReply(0, $prefix, @pkg) );
}

####
# Usage: &searchDesc($query);
sub searchDesc {
    my ($dist, $query)	= &getDistroFromStr($_[0]);
    &::DEBUG("searchDesc: dist => '$dist', query => '$query'.");
    $query =~ s/^\s+|\s+$//g;

    # start of search.
    my $start_time = &::timeget();
    &::status("Debian: starting desc search.");

    my $files;
    my ($bad,$good) = (0,0);
    my %urls = %urlpackages;

    foreach (keys %urlpackages) {
	s/##DIST/$dist/g;

	if (! -f $_) {
	    $bad++;
	    next;
	}

	$good++;
	$files .= " ".$_;
    }

    &::DEBUG("good = $good, bad = $bad...");

    if ($good == 0 and $bad != 0) {
	my %urls = &fixDist($dist, %urlpackages);
	&::DEBUG("deb: download 2c.");
	if (!&DebianDownload($dist, %urls)) {
	    &::ERROR("Debian(sD): could not download files.");
	    return;
	}
    }

    my $regex	= $query;
    $regex	=~ s/\./\\./g;
    $regex	=~ s/\*/\\S*/g;
    $regex	=~ s/\?/./g;

    my (%desc, $package);
    open(IN,"zegrep -h '^Package|^Description' $files |");
    while (<IN>) {
	if (/^Package: (\S+)$/) {
	    $package = $1;
	} elsif (/^Description: (.*)$/) {
	    my $desc = $1;
	    next unless (eval { $desc =~ /$regex/i });
	    return unless &checkEval($@);

	    if ($package eq "") {
		&::WARN("sD: package == NULL?");
		next;
	    }
	    $desc{$package} = $desc;
	    $package = "";
	} else {
	    &::WARN("invalid line: '$_'.");
	}
    }
    close IN;

    # show how long it took.
    my $delta_time = &::timedelta($start_time);
    &::status(sprintf("Debian: %.02f sec to complete query.", $delta_time)) if ($delta_time > 0);

    return keys %desc;
}

####
# Usage: &generateIncoming();
sub generateIncoming {
    my $pkgfile  = "debian/Packages-incoming";
    my $idxfile  = $pkgfile.".idx";
    my $stale	 = 0;
    $stale++ if (&::isStale($pkgfile.".gz", $refresh));
    $stale++ if (&::isStale($idxfile, $refresh));
    &::DEBUG("gI: stale => '$stale'.");
    return 0 unless ($stale);

    ### STATIC URL.
    my %ftp = &::ftpList("llug.sep.bnl.gov", "/pub/debian/Incoming/");

    if (!open(PKG,">$pkgfile")) {
	&::ERROR("cannot write to pkg $pkgfile.");
	return 0;
    }
    if (!open(IDX,">$idxfile")) {
	&::ERROR("cannot write to idx $idxfile.");
	return 0;
    }

    print IDX "*$pkgfile.gz\n";
    my $file;
    foreach $file (sort keys %ftp) {
	next unless ($file =~ /deb$/);

	if ($file =~ /^(\S+)\_(\S+)\_(\S+)\.deb$/) {
	    print IDX "$1\n";
	    print PKG "Package: $1\n";
	    print PKG "Version: $2\n";
	    print PKG "Architecture: ", (defined $4) ? $4 : "all", "\n";
	}
	print PKG "Filename: $file\n";
	print PKG "Size: $ftp{$file}\n";
	print PKG "\n";
    }
    close IDX;
    close PKG;

    system("gzip -9fv $pkgfile");	# lame fix.

    &::status("Debian: generateIncoming() complete.");
}


##############################
# DEBIAN PACKAGE INFO FUNCTIONS.
#########

# Usage: &getPackageInfo($query,$file);
sub getPackageInfo {
    my ($package, $file) = @_;

    if (! -f $file) {
	&::status("gPI: file $file does not exist?");
	return 'NULL';
    }

    my $found = 0;
    my (%pkg, $pkg);

    open(IN, "zcat $file 2>&1 |");

    my $done = 0;
    while (!eof IN) {
	$_ = <IN>;

	next if (/^ \S+/);	# package long description.

	# package line.
	if (/^Package: (.*)\n$/) {
	    $pkg = $1;
	    if ($pkg =~ /^$package$/i) {
		$found++;	# we can use pkg{'package'} instead.
		$pkg{'package'} = $pkg;
	    }

	    next;
	}

	if ($found) {
	    chop;

	    if (/^Version: (.*)$/) {
		$pkg{'version'}		= $1;
	    } elsif (/^Priority: (.*)$/) {
		$pkg{'priority'}	= $1;
	    } elsif (/^Section: (.*)$/) {
		$pkg{'section'}		= $1;
	    } elsif (/^Size: (.*)$/) {
		$pkg{'size'}		= $1;
	    } elsif (/^Installed-Size: (.*)$/i) {
		$pkg{'installed'}	= $1;
	    } elsif (/^Description: (.*)$/) {
		$pkg{'desc'}		= $1;
	    } elsif (/^Filename: (.*)$/) {
		$pkg{'find'}		= $1;
	    } elsif (/^Pre-Depends: (.*)$/) {
		$pkg{'depends'}		= "pre-depends on $1";
	    } elsif (/^Depends: (.*)$/) {
		if (exists $pkg{'depends'}) {
		    $pkg{'depends'} .= "; depends on $1";
		} else {
		    $pkg{'depends'} = "depends on $1";
		}
	    } elsif (/^Maintainer: (.*)$/) {
		$pkg{'maint'} = $1;
	    } elsif (/^Provides: (.*)$/) {
		$pkg{'provides'} = $1;
	    } elsif (/^Suggests: (.*)$/) {
		$pkg{'suggests'} = $1;
	    } elsif (/^Conflicts: (.*)$/) {
		$pkg{'conflicts'} = $1;
	    }

###	    &::DEBUG("=> '$_'.");
	}

	# blank line.
	if (/^$/) {
	    undef $pkg;
	    last if ($found);
	    next;
	}

	next if (defined $pkg);
    }

    close IN;

    %pkg;
}

# Usage: &infoPackages($query,$package);
sub infoPackages {
    my ($query,$dist,$package) = ($_[0], &getDistroFromStr($_[1]));

    &::status("Debian: Searching for package '$package' in '$dist'.");

    # download packages file.
    # hrm...
    my %urls = &fixDist($dist, %urlpackages);
    if ($dist ne "incoming") {
	&::DEBUG("deb: download 3.");
	if (!&DebianDownload($dist, %urls)) {	# no good download.
	    &::WARN("Debian(iP): could not download ANY files.");
	}
    }

    # check if the package is valid.
    my $incoming = 0;
    my @files = &validPackage($package, $dist);
    if (!scalar @files) {
	&::status("Debian: no valid package found; checking incoming.");
	@files = &validPackage($package, "incoming");
	if (scalar @files) {
	    &::status("Debian: cool, it exists in incoming.");
	    $incoming++;
	} else {
	    &::msg($::who, "Package '$package' does not exist.");
	    return 0;
	}
    }

    if (scalar @files > 1) {
	&::WARN("same package in more than one file; random.");
	&::DEBUG("THIS SHOULD BE FIXED SOMEHOW!!!");
	$files[0] = &::getRandom(@files);
    }

    if (! -f $files[0]) {
	&::WARN("files[0] ($files[0]) doesn't exist.");
	&::msg($::who, "WARNING: $files[0] does not exist? FIXME");
	return 'NULL';
    }

    ### TODO: if specific package is requested, note down that a version
    ###		exists in incoming.

    my $found = 0;
    my $file = $files[0];
    my ($pkg);

    ### TODO: use fe, dump to a hash. if only one version of the package
    ###		exists. do as normal otherwise list all versions.
    if (! -f $file) {
	&::ERROR("D:iP: file '$file' DOES NOT EXIST!!! should never happen.");
	return 0;
    }
    my %pkg = &getPackageInfo($package, $file);

    # 'fm'-like output.
    if ($query eq "info") {
	if (scalar keys %pkg > 5) {
	    $pkg{'info'}  = "\002(\002". $pkg{'desc'} ."\002)\002";
	    $pkg{'info'} .= ", section ".$pkg{'section'};
	    $pkg{'info'} .= ", is ".$pkg{'priority'};
#	    $pkg{'info'} .= ". Version: \002$pkg{'version'}\002";
	    $pkg{'info'} .= ". Version: \002$pkg{'version'}\002 ($dist)";
	    $pkg{'info'} .= ", Packaged size: \002". int($pkg{'size'}/1024) ."\002 kB";
	    $pkg{'info'} .= ", Installed size: \002$pkg{'installed'}\002 kB";

	    if ($incoming) {
		&::status("iP: info requested and pkg is in incoming, too.");
		my %incpkg = &getPackageInfo($query, "debian/Packages-incoming");

		if (scalar keys %incpkg) {
		   $pkg{'info'} .= ". Is in incoming ($incpkg{'file'}).";
		} else {
		    &::ERROR("iP: pkg $query is in incoming but we couldn't get any info?");
		}
	    }
	} else {
	    &::DEBUG("running debianCheck() due to problems (".scalar(keys %pkg).").");
	    &debianCheck();
	    &::DEBUG("end of debianCheck()");

	    &::msg($::who,"Debian: Package appears to exist but I could not retrieve info about it...");
	    return;
	}
    } 

    if ($dist eq "incoming") {
	$pkg{'info'} .= "Version: \002$pkg{'version'}\002";
	$pkg{'info'} .= ", Packaged size: \002". int($pkg{'size'}/1024) ."\002 kB";
	$pkg{'info'} .= ", is in incoming!!!";
    }

    if (!exists $pkg{$query}) {
	if ($query eq "suggests") {
	    $pkg{$query} = "has no suggestions";
	} elsif ($query eq "conflicts") {
	    $pkg{$query} = "does not conflict with any other package";
	} elsif ($query eq "depends") {
	    $pkg{$query} = "does not depend on anything";
	} elsif ($query eq "maint") {
	    $pkg{$query} = "has no maintainer";
	} else {
	    $pkg{$query} = "has nothing about $query";
	}
    }

    &::pSReply("$package: $pkg{$query}");
}

# Usage: &infoStats($dist);
sub infoStats {
    my ($dist)	= @_;
    $dist	= &getDistro($dist);
    return unless (defined $dist);

    &::DEBUG("infoS: dist => '$dist'.");

    # download packages file if needed.
    my %urls = &fixDist($dist, %urlpackages);
    &::DEBUG("deb: download 4.");
    if (!&DebianDownload($dist, %urls)) {
	&::WARN("Debian(iS): could not download ANY files.");
	&::msg($::who, "Debian(iS): internal error.");
	return;
    }

    my %stats;
    my %total;
    my $file;
    foreach $file (keys %urlpackages) {
	$file =~ s/##DIST/$dist/g;	# won't work for incoming.
	&::DEBUG("file => '$file'.");
	if (exists $stats{$file}{'count'}) {
	    &::DEBUG("hrm... duplicate open with $file???");
	    next;
	}

	open(IN,"zcat $file 2>&1 |");

	if (! -e $file) {
	    &::DEBUG("iS: $file does not exist.");
	    next;
	}

	while (!eof IN) {
	    $_ = <IN>;

	    next if (/^ \S+/);	# package long description.

	    if (/^Package: (.*)\n$/) {		# counter.
		$stats{$file}{'count'}++;
		$total{'count'}++;
	    } elsif (/^Maintainer: .* <(\S+)>$/) {
		$stats{$file}{'maint'}{$1}++;
		$total{'maint'}{$1}++;
	    } elsif (/^Size: (.*)$/) {		# compressed size.
		$stats{$file}{'csize'}	+= $1;
		$total{'csize'}		+= $1;
	    } elsif (/^i.*size: (.*)$/i) {	# installed size.
		$stats{$file}{'isize'}	+= $1;
		$total{'isize'}		+= $1;
	    }

###	    &::DEBUG("=> '$_'.");
	}
	close IN;
    }

    ### TODO: don't count ppl with multiple email addresses.

    &::pSReply(
	"Debian Distro Stats on $dist... ".
	"\002$total{'count'}\002 packages, ".
	"\002".scalar(keys %{ $total{'maint'} })."\002 maintainers, ".
	"\002". int($total{'isize'}/1024)."\002 MB installed size, ".
	"\002". int($total{'csize'}/1024/1024)."\002 MB compressed size."
    );

### TODO: do individual stats? if so, we need _another_ arg.
#    foreach $file (keys %stats) {
#	foreach (keys %{ $stats{$file} }) {
#	    &::DEBUG("  '$file' '$_' '$stats{$file}{$_}'.");
#	}
#    }

    return;
}



###
# HELPER FUNCTIONS FOR INFOPACKAGES...
###

# Usage: &generateIndex();
sub generateIndex {
    my (@dists)	= @_;
    &::status("Debian: !!! generateIndex($dists[0]) called !!!");
    if (!scalar @dists or $dists[0] eq '') {
	&::ERROR("gI: no dists to generate index.");
	return 1;
    }

    foreach (@dists) {
	my $dist = &getDistro($_); # incase the alias is returned, possible?
	my $idx  = "debian/Packages-$dist.idx";
	&::DEBUG("gI: dist => $dist.");
	&::DEBUG("gI: idx  => $idx.");
	&::DEBUG("gI: r    => $refresh.");

	# TODO: check if any of the Packages file have been updated then
	#	regenerate it, even if it's not stale.
	# TODO: also, regenerate the index if the packages file is newer
	#	than the index.
	next unless (&::isStale($idx, $refresh));

	if (/^incoming$/i) {
	    &::DEBUG("gIndex: calling generateIncoming()!");
	    &generateIncoming();
	    next;
	}

	if (/^woody$/i) {
	    &::DEBUG("Copying old index of woody to -old");
	    system("cp $idx $idx-old");
	}

	&::DEBUG("gIndeX: calling DebianDownload($dist, ...).");
	&DebianDownload($dist, %urlpackages);

	&::status("Debian: generating index for '$dist'.");
	if (!open(OUT,">$idx")) {
	    &::ERROR("cannot write to $idx.");
	    return 0;
	}

	my $packages;
	foreach $packages (keys %urlpackages) {
	    $packages =~ s/##DIST/$dist/;

	    if (! -e $packages) {
		&::ERROR("gIndex: '$packages' does not exist?");
		next;
	    }

	    print OUT "*$packages\n";
	    open(IN,"zcat $packages |");

	    while (<IN>) {
		next unless (/^Package: (.*)\n$/);
		print OUT $1."\n";
	    }
	    close IN;
	}
	close OUT;
    }

    return 1;
}

# Usage: &validPackage($package, $dist);
sub validPackage {
    my ($package,$dist) = @_;
    my @files;
    my $file;

    ### this majorly sucks, we need some standard in place.
    # why is this needed... need to investigate later.
    my $olddist	= $dist;
    $dist = &getDistro($dist);

    &::DEBUG("D: validPackage($package, $dist) called.");

    my $error = 0;
    while (!open(IN, "debian/Packages-$dist.idx")) {
	if ($error) {
	    &::ERROR("Packages-$dist.idx does not exist (#1).");
	    return;
	}

	&generateIndex($dist);

	$error++;
    }

    my $count = 0;
    while (<IN>) {
	if (/^\*(.*)\n$/) {
	    $file = $1;
	    next;
	}

	if (/^\Q$package\E\n$/) {
	    push(@files,$file);
	}
	$count++;
    }
    close IN;

    &::VERB("vP: scanned $count items in index.",2);

    return @files;
}

sub searchPackage {
    my ($dist, $query) = &getDistroFromStr($_[0]);
    my $file = "debian/Packages-$dist.idx";
    my @files;
    my $error	= 0;
    my $warn	= 0;

    if ($query =~ tr/A-Z/a-z/) {
	$warn++;
    }

    &::status("Debian: Search package matching '$query' in '$dist'.");
    unlink $file if ( -z $file);

    while (!open(IN, $file)) {
	if ($dist eq "incoming") {
	    &::DEBUG("sP: dist == incoming; calling gI().");
	    &generateIncoming();
	}

	if ($error) {
	    &::ERROR("could not generate index ($file)!!!");
	    return;
	}

	$error++;
	&::DEBUG("should we be doing this?");
	&generateIndex(($dist));
    }

    while (<IN>) {
	chop;

	if (/^\*(.*)$/) {
	    $file = $1;

	    if (&::isStale($file, $refresh)) {
		&::DEBUG("STALE $file! regen.");
		&generateIndex(($dist));
###		@files = searchPackage("$query $dist");
		&::DEBUG("EVIL HACK HACK HACK.");
		last;
	    }

	    next;
	}

	if (/\Q$query\E/) {
	    push(@files,$_);
	}
    }
    close IN;

    if (scalar @files and $warn) {
	&::msg($::who, "searching for package name should be fully lowercase!");
    }

    return @files;
}

sub getDistro {
    my $dist = $_[0];

    if (!defined $dist or $dist eq "") {
	&::DEBUG("gD: dist == NULL; dist = defaultdist.");
	$dist = $defaultdist;
    }

    if ($dist =~ /^(slink|hamm|rex|bo)$/i) {
	&::DEBUG("Debian: deprecated version ($dist).");
	&::msg($::who, "Debian: deprecated distribution version.");
	return;
    }

    if (exists $dists{$dist}) {
	&::VERB("gD: returning dists{$dist} ($dists{$dist})",2);
	return $dists{$dist};

    } else {
	if (!grep /^\Q$dist\E$/i, %dists) {
	    &::msg($::who, "invalid dist '$dist'.");
	    return;
	}

	&::VERB("gD: returning $dist (no change or conversion)",2);
	return $dist;
    }
}

sub getDistroFromStr {
    my ($str) = @_;
    my $dists	= join '|', %dists;
    my $dist	= $defaultdist;

    if ($str =~ s/\s+($dists)$//i) {
	$dist = &getDistro(lc $1);
	$str =~ s/\\+$//;
    }
    $str =~ s/\\([\$\^])/$1/g;

    return($dist,$str);
}

sub fixDist {
    my ($dist, %urls) = @_;
    my %new;
    my ($key,$val);

    while (($key,$val) = each %urls) {
	$key =~ s/##DIST/$dist/;
	$val =~	s/##DIST/$dist/;
	### TODO: what should we do if the sar wasn't done.
	$new{$key} = $val;
    }
    return %new;
}

sub DebianFind {
    ### H-H-H-HACK HACK HACK :)
    my ($str) = @_;
    my ($dist, $query) = &getDistroFromStr($str);
    my @results = sort &searchPackage($str);

    if (!scalar @results) {
	&::Forker("debian", sub { &searchContents($str); } );
    } elsif (scalar @results == 1) {
	&::status("searchPackage returned one result; getting info of package instead!");
	&::Forker("debian", sub { &infoPackages("info", "$results[0] $dist"); } );
    } else {
	my $prefix = "Debian Package Listing of '$query' ";
	&::pSReply( &::formListReply(0, $prefix, @results) );
    }
}

sub debianCheck {
    my $dir	= "debian/";
    my $error	= 0;

    &::status("debianCheck() called.");

    ### TODO: remove the following loop (check if dir exists before)
    while (1) {
	last if (opendir(DEBIAN, $dir));
	if ($error) {
	    &::ERROR("dC: cannot opendir debian.");
	    return;
	}
	mkdir $dir, 0755;
	$error++;
    }

    my $retval = 0;
    my $file;
    while (defined($file = readdir DEBIAN)) {
	next unless ($file =~ /(gz|bz2)$/);

	my $exit = system("gzip -t '$dir/$file'");
	next unless ($exit);
	&::DEBUG("hmr... => ".(time() - (stat($file))[8])."'.");
	next unless (time() - (stat($file))[8] > 3600);

	&::DEBUG("dC: exit => '$exit'.");
	&::WARN("dC: '$dir/$file' corrupted? deleting!");
	unlink $dir."/".$file;
	$retval++;
    }

    return $retval;
}

sub checkEval {
    my($str)	= @_;

    if ($str) {
	&::WARN("cE: $str");
	return 0;
    } else {
	return 1;
    }
}

sub searchDescFE {
    &::DEBUG("FE called for searchDesc");
    my ($query)	= @_;
    my @list = &searchDesc($query);

    if (!scalar @list) {
	my $prefix = "Debian Desc Search of '$query' ";
	&::pSReply( &::formListReply(0, $prefix, ) );
    } elsif (scalar @list == 1) {	# list = 1.
	&::DEBUG("list == 1; showing package info of '$list[0]'.");
	&infoPackages("info", $list[0]);
    } else {				# list > 1.
	my $prefix = "Debian Desc Search of '$query' ";
	&::pSReply( &::formListReply(0, $prefix, @list) );
    }
}

1;
