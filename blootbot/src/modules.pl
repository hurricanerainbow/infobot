#
#  modules.pl: pseudo-Module handler
#      Author: xk <xk@leguin.openprojects.net>
#     Version: v0.2 (20000629)
#     Created: 20000624
#

if (&IsParam("useStrict")) { use strict; }

###
### REQUIRED MODULES.
###

eval "use IO::Socket";
if ($@) {
    &ERROR("no IO::Socket?");
    exit 1;
}
&showProc(" (IO::Socket)");

### MODULES.
%myModules = (
	"countdown"	=> "Countdown.pl",
	"allowDNS"	=> "DNS.pl",
	"debian"	=> "Debian.pl",
	"debianExtra"	=> "DebianExtra.pl",
	"dict"		=> "Dict.pl",
	"dumpvars"	=> "DumpVars.pl",
	"factoids"	=> "Factoids.pl",
	"freshmeat"	=> "Freshmeat.pl",
	"kernel"	=> "Kernel.pl",
	"ircdcc"	=> "UserDCC.pl",
	"perlMath"	=> "Math.pl",
	"quote"		=> "Quote.pl",
	"rootwarn"	=> "RootWarn.pl",
	"search"	=> "Search.pl",
	"slashdot"	=> "Slashdot3.pl",
	"topic"		=> "Topic.pl",
	"units"		=> "Units.pl",
	"uptime"	=> "Uptime.pl",
	"userinfo"	=> "UserInfo.pl",
	"wwwsearch"	=> "W3Search.pl",
	"whatis"	=> "WhatIs.pl",
	"wingate"	=> "Wingate.pl",
	"insult"	=> "insult.pl",
	"nickometer"	=> "nickometer.pl",
);
@myModulesLoadNow	= ('topic', 'uptime',);
@myModulesReloadNot	= ('IRC/Irc.pl','IRC/Schedulers.pl');

sub loadCoreModules {
    if (!opendir(DIR, $infobot_src_dir)) {
	&ERROR("can't open source directory $infobot_src_dir: $!");
	exit 1;
    }

    &status("Loading CORE modules...");

    while (defined(my $file = readdir DIR)) {
	next unless $file =~ /\.pl$/;
	next unless $file =~ /^[A-Z]/;
	my $mod = "$infobot_src_dir/$file";
	### TODO: use eval and exit gracefully?
	require $mod;
	$moduleAge{$mod} = (stat $mod)[9];
	&showProc(" ($file)") if (&IsParam("DEBUG"));
    }
    closedir DIR;
}

sub loadDBModules {
    &status("Loading DB modules...");

    if ($param{'DBType'} =~ /^mysql$/i) {
	eval "use DBI";
	if ($@) {
	    &ERROR("libdbd-mysql-perl is not installed!");
	    exit 1;
	}
	&showProc(" (DBI // mysql)");

	&status("  using MySQL support.");
	require "$infobot_src_dir/db_mysql.pl";

    } elsif ($param{'DBType'} =~ /^pgsql$/i) {
	eval "use Pg";
	if ($@) {
	    &ERROR("libpgperl is not installed!");
	    exit 1;
	}
	&showProc(" (Pg // postgreSQLl)");

	&status("  using PostgreSQL support.");
	require "$infobot_src_dir/db_pgsql.pl";
    } elsif ($param{'DBType'} =~ /^dbm$/i) {

	&status("  using Berkeley DBM 1.85/2.0 support.");
	require "$infobot_src_dir/db_dbm.pl";
    } else {

	&status("DB support DISABLED.");
	return;
    }
}

sub loadFactoidsModules {
    &status("Loading Factoids modules...");

    if (!&IsParam("factoids")) {
	&status("Factoid support DISABLED.");
	return;
    }

    if (!opendir(DIR, "$infobot_src_dir/Factoids")) {
	&ERROR("can't open source directory Factoids: $!");
	exit 1;
    }

    while (defined(my $file = readdir DIR)) {
	next unless $file =~ /\.pl$/;
	next unless $file =~ /^[A-Z]/;
	my $mod = "$infobot_src_dir/Factoids/$file";
	### TODO: use eval and exit gracefully?
	require $mod;
	$moduleAge{$mod} = (stat $mod)[9];
	&showProc(" ($file)") if (&IsParam("DEBUG"));
    }
    closedir DIR;
}

sub loadIRCModules {
    &status("Loading IRC modules...");
    if (&whatInterface() =~ /IRC/) {
	eval "use Net::IRC";
	if ($@) {
	    &ERROR("libnet-irc-perl is not installed!");
	    exit 1;
	}
	&showProc(" (Net::IRC)");
    } else {
	&status("IRC support DISABLED.");
	return;
    }

    if (!opendir(DIR, "$infobot_src_dir/IRC")) {
	&ERROR("can't open source directory Factoids: $!");
	exit 1;
    }

    while (defined(my $file = readdir DIR)) {
	next unless $file =~ /\.pl$/;
	next unless $file =~ /^[A-Z]/;
	my $mod = "$infobot_src_dir/IRC/$file";
	### TODO: use eval and exit gracefully?
	require $mod;
	$moduleAge{$mod} = (stat $mod)[9];
	&showProc(" ($file)") if (&IsParam("DEBUG"));
    }
    closedir DIR;
}

sub loadMyModulesNow {
    my $loaded = 0;
    my $total  = 0;

    &status("Loading MyModules...");
    foreach (@myModulesLoadNow) {
	$total++;

	if (!exists $param{$_}) {
	    &DEBUG("myModule: $myModules{$_} not loaded.");
	    next;
	}
	&loadMyModule($myModules{$_});
	$loaded++;
    }

    &status("Modules: Loaded/Total [$loaded/$total]");
}

### rename to modulesReload?
sub reloadModules {
##    my @check = map { $myModules{$_} } keys %myModules;
##    push(@check, map { substr($_,2) } keys %moduleAge);
    my @check = map { substr($_,2) } keys %moduleAge;

    &DEBUG("rM: moduleAge must be in src/BLAH format?");
    foreach (keys %moduleAge) {
	&DEBUG("rM: moduleAge{$_} => '...'.");
    }

    foreach (@check) {
	my $mod = $_;
	my $file = (grep /\/$mod/, keys %INC)[0];

	if (!defined $file) {
	    &DEBUG("rM: mod '$mod' was not found in \%INC.");
	    next;
	}

	if (! -f $file) {
	    &DEBUG("rM: file '$file' does not exist?");
	    next;
	}

	my $age = (stat $file)[9];
	next if ($age == $moduleAge{$file});

	if (grep /$mod/, @myModulesReloadNot) {
	    &DEBUG("rM: SHOULD NOT RELOAD $mod!!!");
	    next;
	}

	&DEBUG("rM: (loading) => '$mod' or ($_).");
	delete $INC{$file};
	eval "require \"$file\"";
	if (@$) {
	    &DEBUG("rM: failure: @$");
	} else {
	    &DEBUG("rM: good! (reloaded)");
	}
    }
    &DEBUG("rM: Done.");
}

###
### OPTIONAL MODULES.
###

local %perlModulesLoaded  = ();
local %perlModulesMissing = ();

sub loadPerlModule {
    return 0 if (exists $perlModulesMissing{$_[0]});
    return 1 if (exists $perlModulesLoaded{$_[0]});

    eval "use $_[0]";
    if ($@) {
	&WARN("Module: $_[0] is not installed!");
	$perlModulesMissing{$_[0]} = 1;
	return 0;
    } else {
	$perlModulesLoaded{$_[0]} = 1;
	&status("Module: Loaded $_[0] ...");
	&showProc(" ($_[0])");
	return 1;
    }
}

sub loadMyModule {
    my ($tmp) = @_;
    if (!defined $tmp) {
	&WARN("loadMyModule: module is NULL.");
	return 0; 
    }

    my ($modulebase, $modulefile);
    if (exists $myModules{$tmp}) {
	($modulename, $modulebase) = ($tmp, $myModules{$tmp});
    } else {
	$modulebase = $tmp;
    }
    my $modulefile = "$infobot_src_dir/Modules/$modulebase";

    return 1 if (grep /$modulefile/, keys %INC);

    if (! -f $modulefile) {
	&ERROR("lMM: module ($modulebase) does not exist.");
	if ($$ == $infobot_pid) {	# parent.
	    &shutdown() if (defined $shm and defined $dbh);
	} else {			# child.
	    &delForked($modulename);
	}

	exit 1;
    }

    eval "require \"$modulefile\"";
    if ($@) {
	&ERROR("cannot load my module: $modulebase");
	if ($infobot_pid == $$) {	# parent.
	    &shutdown() if (defined $shm and defined $dbh);
	} else {			# child.
	    &delForked($modulebase);
	}

	exit 1;
    } else {
	$moduleAge{$modulefile} = (stat $modulefile)[9];
	&DEBUG("lMM: setting moduleAge{$modulefile} = time();");

	&status("myModule: Loaded $modulebase ...");
	&showProc(" ($modulebase)");
	return 1;
    }
}

### this chews 3megs on potato, 300 kB on slink.
$no_syscall = 0;
###eval "require 'sys/syscall.ph'";
#if ($@) {
#    &WARN("sys/syscall.ph has not been installed//generated. gettimeofday
#will use time() instead");
    $no_syscall = 1;
#}
#&showProc(" (syscall)");

1;
