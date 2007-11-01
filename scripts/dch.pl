#! /usr/bin/perl -w

# debchange: update the debian changelog using your favorite visual editor
# For options, see the usage message below.
#
# When creating a new changelog section, if either of the environment
# variables DEBEMAIL or EMAIL is set, debchange will use this as the
# uploader's email address (with the former taking precedence), and if
# DEBFULLNAME or NAME is set, it will use this as the uploader's full name.
# Otherwise, it will take the standard values for the current user or,
# failing that, just copy the values from the previous changelog entry.
#
# Originally by Christoph Lameter <clameter@debian.org>
# Modified extensively by Julian Gilbey <jdg@debian.org>
#
# Copyright 1999-2005 by Julian Gilbey 
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use 5.008;  # We're using PerlIO layers
use strict;
use open ':utf8';  # changelogs are written with UTF-8 encoding
use filetest 'access';  # use access rather than stat for -w
use Encode 'decode_utf8';  # for checking whether user names are valid
use Getopt::Long;
use File::Copy;
use File::Basename;
use Cwd;

BEGIN {
    # Load the URI::Escape module safely
    eval { require URI::Escape; };
    if ($@) {
	my $progname = basename $0;
	if ($@ =~ /^Can\'t locate URI\/Escape\.pm/) {
	    die "$progname: you must have the liburi-perl package installed\nto use this script\n";
	}
	die "$progname: problem loading the URI::Escape module:\n  $@\nHave you installed the liburi-perl package?\n";
    }
    import URI::Escape;
}

# Predeclare functions
sub fatal($);
my $warnings = 0;

# And global variables
my $progname = basename($0);
my $modified_conf_msg;
my %env;
my $CHGLINE;  # used by the format O section at the end

sub usage () {
    print <<"EOF";
Usage: $progname [options] [changelog entry]
Options:
  -a, --append
         Append a new entry to the current changelog
  -i, --increment
         Increase the Infobot release number, adding a new changelog entry
  -v <version>, --newversion=<version>
         Add a new changelog entry with version number specified
  -e, --edit
         Don't change version number or add a new changelog entry, just
         update the changelog's stamp and open up an editor
  -r, --release
         Update the changelog timestamp.
  -d, --fromdirname
         Add a new changelog entry with version taken from the directory name
  -p, --preserve
         Preserve the directory name
  --no-preserve
         Do not preserve the directory name (default)
  --help, -h
         Display this help message and exit
  --version
         Display version information
  At most one of -a, -i, -e, -r, -v, -d (or their long equivalents)
  may be used.
  With no options, one of -i or -a is chosen by looking for a .upload
  file in the parent directory and checking its contents.

Default settings modified by devscripts configuration files:
$modified_conf_msg
EOF
}

sub version () {
    print <<"EOF";
This is $progname, ripped from the Debian devscripts package, version 2.10.9
This code is copyright 1999-2003 by Julian Gilbey, all rights reserved.
Based on code by Christoph Lameter.
This program comes with ABSOLUTELY NO WARRANTY.
You are free to redistribute this code under the terms of the
GNU General Public License, version 2 or later.
EOF
}

# Start by setting default values
my $check_dirname_level = 1;
my $check_dirname_regex = 'PACKAGE(-.*)?';
my $opt_p = 0;
my $opt_query = 1;
my $opt_release_heuristic = 'log';
my $opt_multimaint = 1;
my $opt_multimaint_merge = 0;
my $opt_tz = undef;
my $opt_mainttrailer = 0;

# Next, read configuration files and then command line
# The next stuff is boilerplate

if (@ARGV and $ARGV[0] =~ /^--no-?conf$/) {
    $modified_conf_msg = "  (no configuration files read)";
    shift;
} else {
    my @config_files = ('~/.infobot-dev.conf');
    my %config_vars = (
		       'CHANGE_PRESERVE' => 'no',
		       'CHANGE_TZ' => $ENV{TZ}, # undef if TZ unset
		       );
    $config_vars{'CHANGE_TZ'} ||= '';
    my %config_default = %config_vars;
    
    my $shell_cmd;
    # Set defaults
    foreach my $var (keys %config_vars) {
	$shell_cmd .= qq[$var="$config_vars{$var}";\n];
    }
    $shell_cmd .= 'for file in ' . join(" ",@config_files) . "; do\n";
    $shell_cmd .= '[ -f $file ] && . $file; done;' . "\n";
    # Read back values
    foreach my $var (keys %config_vars) { $shell_cmd .= "echo \$$var;\n" }
    my $shell_out = `/bin/bash -c '$shell_cmd'`;
    @config_vars{keys %config_vars} = split /\n/, $shell_out, -1;

    # Check validity
    $config_vars{'CHANGE_PRESERVE'} =~ /^(yes|no)$/
	or $config_vars{'CHANGE_PRESERVE'}='no';

    foreach my $var (sort keys %config_vars) {
	if ($config_vars{$var} ne $config_default{$var}) {
	    $modified_conf_msg .= "  $var=$config_vars{$var}\n";
	}
    }
    $modified_conf_msg ||= "  (none)\n";
    chomp $modified_conf_msg;

    $opt_p = $config_vars{'CHANGE_PRESERVE'} eq 'yes' ? 1 : 0;
    $opt_tz = $config_vars{'CHANGE_TZ'};
}

# We use bundling so that the short option behaviour is the same as
# with older debchange versions.
my ($opt_help, $opt_version);
my ($opt_i, $opt_a, $opt_e, $opt_r, $opt_v, $opt_b, $opt_d, $opt_D, $opt_u, $opt_t);
my ($opt_n, $opt_qa, $opt_bpo, $opt_c, $opt_m, $opt_create, $opt_package, @closes);
my ($opt_news);
my ($opt_ignore, $opt_level, $opt_regex, $opt_noconf);

Getopt::Long::Configure('bundling');
GetOptions("help|h" => \$opt_help,
	   "version" => \$opt_version,
	   "i|increment" => \$opt_i,
	   "a|append" => \$opt_a,
	   "e|edit" => \$opt_e,
	   "r|release" => \$opt_r,
	   "v|newversion=s" => \$opt_v,
	   "p" => \$opt_p,
	   "preserve!" => \$opt_p,
	   "release-heuristic=s" => \$opt_release_heuristic,
	   )
    or die "Usage: $progname [options] [changelog entry]\nRun $progname --help for more details\n";

if ($opt_noconf) {
    fatal "--no-conf is only acceptable as the first command-line option!";
}
if ($opt_help) { usage; exit 0; }
if ($opt_version) { version; exit 0; }

# dirname stuff
if ($opt_ignore) {
    fatal "--ignore-dirname has been replaced by --check-dirname-level and\n--check-dirname-regex; run $progname --help for more details";
}

if (defined $opt_level) {
    if ($opt_level =~ /^[012]$/) { $check_dirname_level = $opt_level; }
    else {
	fatal "Unrecognised --check-dirname-level value (allowed are 0,1,2)";
    }
}

if (defined $opt_regex) { $check_dirname_regex = $opt_regex; }

# Only allow at most one non-help option
fatal "Only one of -a, -i, -e, -r, -v, -d is allowed;\ntry $progname --help for more help"
    if ($opt_i?1:0) + ($opt_a?1:0) + ($opt_e?1:0) + ($opt_r?1:0) + ($opt_v?1:0) + ($opt_d?1:0) + ($opt_n?1:0) + ($opt_qa?1:0) + ($opt_bpo?1:0) > 1;

my $changelog_path = $opt_c || $ENV{'CHANGELOG'} || 'Changelog';
my $real_changelog_path = $changelog_path;
if ($changelog_path ne 'Changelog') {
    $check_dirname_level = 0;
}

if ($opt_create) {
    if ($opt_a || $opt_i || $opt_e || $opt_r || $opt_b || $opt_n || $opt_qa || $opt_bpo) {
	warn "$progname warning: ignoring -a/-i/-e/-r/-b/-n/--qa/--bpo options with --create\n";
	$warnings++;
    }
    if ($opt_package && $opt_d) {
	fatal "Can only use one of --package and -d";
    }
}


@closes = split(/,/, join(',', @closes));
map { s/^\#//; } @closes;  # remove any leading # from bug numbers

# We'll process the rest of the command line later.

# Look for the changelog
my $chdir = 0;
if (! $opt_create) {
    if ($changelog_path eq 'Changelog' or $opt_news) {
	until (-f $changelog_path) {
	    $chdir = 1;
	    chdir '..' or fatal "Can't chdir ..: $!";
	    if (cwd() eq '/') {
		fatal "Cannot find $changelog_path anywhere!\nAre you in the source code tree?\n(You could use --create if you wish to create this file.)";
	    }
	}
	
	# Can't write, so stop now.
	if (! -w $changelog_path) {
	    fatal "$changelog_path is not writable!";
	}
    }
    else {
	unless (-f $changelog_path) {
	    fatal "Cannot find $changelog_path!\nAre you in the correct directory?\n(You could use --create if you wish to create this file.)";
	}

	# Can't write, so stop now.
	if (! -w $changelog_path) {
	    fatal "$changelog_path is not writable!";
	}
    }
}
else {  # $opt_create
    unless (-d dirname $changelog_path) {
	fatal "Cannot find " . (dirname $changelog_path) . " directory!\nAre you in the correct directory?";
    }
    if (-f $changelog_path) {
	fatal "File $changelog_path already exists!";
    }
    unless (-w dirname $changelog_path) {
	fatal "Cannot find " . (dirname $changelog_path) . " directory!\nAre you in the correct directory?";
    }
    if ($opt_news && ! -f 'debian/changelog') {
	fatal "I can't create $opt_news without debian/changelog present";
    }
}

#####

# Find the current version number etc.
my %changelog;
my $PACKAGE = 'PACKAGE';
my $VERSION = 'VERSION';
my $MAINTAINER = 'MAINTAINER';
my $EMAIL = 'EMAIL';
my $DISTRIBUTION = 'UNRELEASED';
my $CHANGES = '';

# Clean up after old versions of debchange
if (-f "debian/RELEASED") {
    unlink("debian/RELEASED");
}

if ( -e "$changelog_path.clg" ) {
    fatal "The backup file $changelog_path.clg already exists --\n" .
		  "please move it before trying again";
}


# Is this a native Debian package, i.e., does it have a - in the
# version number?
(my $EPOCH) = ($VERSION =~ /^(\d+):/);
(my $SVERSION=$VERSION) =~ s/^\d+://;
(my $UVERSION=$SVERSION) =~ s/-[^-]*$//;

# Check, sanitise and decode these environment variables
check_env_utf8('FULLNAME');
check_env_utf8('NAME');
check_env_utf8('EMAIL');

if (exists $env{'EMAIL'} and $env{'EMAIL'} =~ /^(.*)\s+<(.*)>$/) {
    $env{'FULLNAME'} = $1 unless exists $env{'FULLNAME'};
    $env{'EMAIL'} = $2;
}
if (! exists $env{'EMAIL'} or ! exists $env{'FULLNAME'}) {
    if (exists $env{'EMAIL'} and $env{'EMAIL'} =~ /^(.*)\s+<(.*)>$/) {
	$env{'FULLNAME'} = $1 unless exists $env{'FULLNAME'};
	$env{'EMAIL'} = $2;
    }
}

# Now use the gleaned values to detemine our MAINTAINER and EMAIL values
if (! $opt_m) {
    if (exists $env{'FULLNAME'}) {
	$MAINTAINER = $env{'FULLNAME'};
    } elsif (exists $env{'NAME'}) {
	$MAINTAINER = $env{'NAME'};
    } else {
	my @pw = getpwuid $<;
	if (defined($pw[6])) {
	    if (my $pw = decode_utf8($pw[6])) {
		$pw =~ s/,.*//;
		$MAINTAINER = $pw;
	    } else {
		warn "$progname warning: passwd full name field for uid $<\nis not UTF-8 encoded; ignoring\n";
		$warnings++;
	    }
	}
    }
    # Otherwise, $MAINTAINER retains its default value of the last
    # changelog entry

    # Email is easier
    if (exists $env{'EMAIL'}) { $EMAIL = $env{'EMAIL'}; }
    elsif (exists $env{'EMAIL'}) { $EMAIL = $env{'EMAIL'}; }
    else {
	my $addr;
	if (open MAILNAME, '/etc/mailname') {
	    chomp($addr = <MAILNAME>);
	    close MAILNAME;
	}
	if (!$addr) {
	    chomp($addr = `hostname --fqdn 2>/dev/null`);
	    $addr = undef if $?;
	}
	if ($addr) {
	    my $user = getpwuid $<;
	    if (!$user) {
		$addr = undef;
	    }
	    else {
		$addr = "$user\@$addr";
	    }
	}
	$EMAIL = $addr if $addr;
    }
    # Otherwise, $EMAIL retains its default value of the last changelog entry
} # if (! $opt_m)

#####

# Get a possible changelog entry from the command line
my $ARGS=join(' ', @ARGV);
my $TEXT=decode_utf8($ARGS);
my $EMPTY_TEXT=0;

if (@ARGV and ! $TEXT) {
    if ($ARGS) {
	warn "$progname warning: command-line changelog entry not UTF-8 encoded; ignoring\n";
	$TEXT='';
    } else {
	$EMPTY_TEXT = 1;
    }
}

# Get the date
my $date_cmd = ($opt_tz ? "TZ=$opt_tz " : "") . "date -R";
chomp(my $DATE=`$date_cmd`);

# Are we going to have to figure things out for ourselves?
if (! $opt_i && ! $opt_v && ! $opt_d && ! $opt_a && ! $opt_e && ! $opt_r &&
    ! $opt_create) {
    # Yes, we are
    if ($opt_release_heuristic eq 'log') {
	my @UPFILES = glob("../$PACKAGE\_$SVERSION\_*.upload");
	if (@UPFILES > 1) {
	    fatal "Found more than one appropriate .upload file!\n" .
	        "Please use an explicit -a, -i or -v option instead.";
	}
	elsif (@UPFILES == 0) { $opt_a = 1 }
	else {
	    open UPFILE, "<${UPFILES[0]}"
		or fatal "Couldn't open .upload file for reading: $!\n" .
		    "Please use an explicit -a, -i or -v option instead.";
	    while (<UPFILE>) {
		if (m%^(s|Successfully uploaded) (/.*/)?\Q$PACKAGE\E\_\Q$SVERSION\E\_[\w\-\+]+\.changes %) {
		   $opt_i = 1;
		   last;
		}
	    }
	    close UPFILE
		or fatal "Problems experienced reading .upload file: $!\n" .
			    "Please use an explicit -a, -i or -v option instead.";
	    if (! $opt_i) {
		warn "$progname warning: A successful upload of the current version was not logged\n" .
		    "in the upload log file; adding log entry to current version.";
		$opt_a = 1;
	    }
	}
    }
}

# Open in anticipation....
unless ($opt_create) {
    open S, $changelog_path or fatal "Cannot open existing $changelog_path: $!";
}
open O, ">$changelog_path.clg"
    or fatal "Cannot write to temporary file: $!";
# Turn off form feeds; taken from perlform
select((select(O), $^L = "")[0]);

# Note that we now have to remove it
my $tmpchk=1;
my ($NEW_VERSION, $NEW_SVERSION, $NEW_UVERSION);
my $line;

if (($opt_i || $opt_n || $opt_qa || $opt_bpo || $opt_v || $opt_d ||
    ($opt_news && $VERSION ne $changelog{'Version'})) && ! $opt_create) {

    # Check that a given explicit version number is sensible.
    if ($opt_v || $opt_d) {
	if($opt_v) {
	    $NEW_VERSION=$opt_v;
	} else {
	    my $pwd = basename(cwd());
	    # The directory name should be <package>-<version>
	    my $version_chars = '0-9a-zA-Z+\.~';
	    $version_chars .= ':' if defined $EPOCH;
	    $version_chars .= '\-' if $UVERSION ne $SVERSION;
	    if ($pwd =~ m/^\Q$PACKAGE\E-([0-9][$version_chars]*)$/) {
		$NEW_VERSION=$1;
		if ($NEW_VERSION eq $UVERSION) {
		    # So it's a Debian-native package
		    if ($SVERSION eq $UVERSION) {
			fatal "New version taken from directory ($NEW_VERSION) is equal to\n" .
			    "the current version number ($UVERSION)!";
		    }
		    # So we just increment the Debian revision
		    warn "$progname warning: Incrementing Infobot revision without altering\n version number.\n";
		    $VERSION =~ /^(.*?)([a-yA-Y][a-zA-Z]*|\d*)$/;
		    my $end = $2;
		    if ($end eq '') {
			fatal "Cannot determine new revision; please use -v option!";
		    }
		    $end++;
		    $NEW_VERSION="$1$end";
		} else {
		    $NEW_VERSION = "$EPOCH:$NEW_VERSION" if defined $EPOCH;
		    $NEW_VERSION .= "-1";
		}
	    } else {
		fatal "The directory name must be <package>-<version> for -d to work!\n" .
		    "No underscores allowed!";
	    }
	    # Don't try renaming the directory in this case!
	    $opt_p=1;
	}

	if (system("dpkg --compare-versions $VERSION lt $NEW_VERSION" .
		  " 2>/dev/null 1>&2")) {
	    if ($opt_b) {
		warn "$progname warning: new version ($NEW_VERSION) is less than\n" .
		    "the current version number ($VERSION).\n";
	    } else {
		fatal "New version specified ($NEW_VERSION) is less than\n" .
		    "the current version number ($VERSION)!  Use -b to force.";
	    }
	}

	($NEW_SVERSION=$NEW_VERSION) =~ s/^\d+://;
	($NEW_UVERSION=$NEW_SVERSION) =~ s/-[^-]*$//;
    }

    # We use the following criteria for the version and release number:
    # the last component of the version number is used as the
    # release number.  If this is not a Debian native package, then the
    # upstream version number is everything up to the final '-', not
    # including epochs.

    if (! $NEW_VERSION) {
	if ($VERSION =~ /(.*?)([a-yA-Y][a-zA-Z]*|\d+)$/i) {
	    my $end=$2;
	    my $start=$1;
	    # If it's not already an NMU make it so
	    # otherwise we can be safe if we behave like dch -i
	    if ($opt_n and (not $start =~ /\.$/ or $VERSION eq $UVERSION)) {
		if ($VERSION eq $UVERSION) {
		    # First NMU of a Debian native package
		    $end .= "-0.1";
		} else {
	    	    $end += 0.1;
		}
	    } elsif ($opt_qa and $start =~/(.*?)-(\d+)\.$/) {
		    # Drop NMU revision when doing a QA upload
		    my $upstream_version = $1;
		    my $debian_revision = $2;
		    $debian_revision++;
		    $start = "$upstream_version-$debian_revision";
		    $end = "";
	    } elsif ($opt_bpo and not $start =~ /~bpo\.$/) {
		# If it's not already a backport make it so
		# otherwise we can be safe if we behave like dch -i
		$end .= "~bpo40+1";
	    } elsif (!$opt_news) {
		# Don't bump the version of a NEWS file in this case as we're
		# using the version from the changelog
		$end++;
	    }
	    $NEW_VERSION = "$start$end";
	    ($NEW_SVERSION=$NEW_VERSION) =~ s/^\d+://;
	    ($NEW_UVERSION=$NEW_SVERSION) =~ s/-[^-]*$//;
	} else {
	    fatal "Error parsing version number: $VERSION";
	}
    }

    $line += 3;
    print O "\n -- $MAINTAINER <$EMAIL>  $DATE\n\n";

    # Copy the old changelog file to the new one
    local $/ = undef;
    print O <S>;
}
elsif (($opt_r || $opt_a) && ! $opt_create) {
    # This means we just have to generate a new * entry in changelog
    # and if a multi-developer changelog is detected, add developer names.
    
    $NEW_VERSION=$VERSION;
    $NEW_SVERSION=$SVERSION;
    $NEW_UVERSION=$UVERSION;

    # Read and discard maintainer line, see who made the
    # last entry, and determine whether there are existing
    # multi-developer changes by the current maintainer.
    $line=-1;
    my ($lastmaint, $nextmaint, $maintline, $count, $lastheader, $lastdist);
    my $savedline = $line;;
    while (<S>) {
	$line++;
	# Start of existing changes by the current maintainer
	if (/^  \[ $MAINTAINER \]$/) {
	    # If there's more than one such block,
	    # we only care about the first
	    $maintline ||= $line;
	}
	elsif (defined $lastmaint) {
	    if (m/^\w[-+0-9a-z.]* \([^\(\) \t]+\)((?:\s+[-+0-9a-z.]+)+)\;/i) {
		$lastheader = $_;
		$lastdist = $1;
		$lastdist =~ s/^\s+//;
		undef $lastdist if $lastdist eq "UNRELEASED";
		# Revert to our previously saved position
		$line = $savedline;
		last;
	    }
	}	
	elsif (/^ --\s+([^<]+)\s+/) {
	    $lastmaint=$1;
	    # Remember where we are so we can skip back afterwards
	    $savedline = $line;
	}

	if (defined $maintline && !defined $nextmaint) {
	    $maintline++;
	}
    }

    if (defined $maintline && defined $nextmaint) {
	# Output the lines up to the end of the current maintainer block
	$count=1;
	$line=$maintline;
	foreach (split /\n/, $CHANGES) {
	    print O $_ . "\n";
	    $count++;
	    last if $count==$maintline;
	}
    } else {
	# The first lines are as we have already found
	print O $CHANGES;
    };

    if (defined $count) {
	# Output the remainder of the changes
	$count=1;
	foreach (split /\n/, $CHANGES) {
	    $count++;
	    next unless $count>$maintline;
	    print O $_ . "\n";
	}
    }

    if ($opt_t && $opt_a) {
	print O "\n -- $changelog{'Maintainer'}  $changelog{'Date'}\n";
    } else {
	print O "\n -- $MAINTAINER <$EMAIL>  $DATE\n";
    }

    if ($lastheader) {
	print O "\n$lastheader";
    }

    # Copy the rest of the changelog file to new one
    # Slurp the rest....
    local $/ = undef;
    print O <S>;
}
elsif ($opt_e && ! $opt_create) {
    # We don't do any fancy stuff with respect to versions or adding
    # entries, we just update the timestamp and open the editor

    print O $CHANGES;

    if ($opt_t) {
	print O "\n -- $changelog{'Maintainer'}  $changelog{'Date'}\n";
    } else {
	print O "\n -- $MAINTAINER <$EMAIL>  $DATE\n";
    }

    # Copy the rest of the changelog file to the new one
    $line=-1;
    while (<S>) { $line++; last if /^ --/; }
    # Slurp the rest...
    local $/ = undef;
    print O <S>;

    # Set the start-line to 0, as we don't know what they want to edit
    $line=0;
}

if ($warnings) {
    if ($warnings>1) {
	warn "$progname: Did you see those $warnings warnings?  Press RETURN to continue...\n";
    } else {
	warn "$progname: Did you see that warning?  Press RETURN to continue...\n";
    }
    my $garbage = <STDIN>;
}

# Now Run the Editor; always run if doing "closes" to give a chance to check
if (!$TEXT and !$EMPTY_TEXT) {
    my $mtime = (stat("$changelog_path.clg"))[9];
    defined $mtime or fatal
	"Error getting modification time of temporary $changelog_path: $!";

    system("sensible-editor +$line $changelog_path.clg") == 0 or
	fatal "Error editing $changelog_path";
}

copy("$changelog_path.clg","$changelog_path") or
    fatal "Couldn't replace $changelog_path with new version: $!";

exit 0;


# Format for standard Debian changelogs
format CHANGELOG =
  * ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    $CHGLINE
 ~~ ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    $CHGLINE
.
# Format for NEWS files.
format NEWS =
  ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    $CHGLINE
~~^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    $CHGLINE
.

my $linecount=0;
sub format_line {
    $CHGLINE=shift;
    my $newentry=shift;

    print O "\n" if $opt_news && ! ($newentry || $linecount);
    $linecount++;
    my $f=select(O);
    if ($opt_news) {
	$~='NEWS';
    }
    else {
	$~='CHANGELOG';
    }
    write O;
    select $f;
}

BEGIN {
    # Initialise the variable
    $tmpchk=0;
}

END {
    if ($tmpchk) {
	unlink "$changelog_path.clg" or
	    warn "$progname warning: Could not remove $changelog_path.clg";
	unlink "$changelog_path.clg~";  # emacs backup file
    }
}

sub fatal($) {
    my ($pack,$file,$line);
    ($pack,$file,$line) = caller();
    (my $msg = "$progname: fatal error at line $line:\n@_\n") =~ tr/\0//d;
    $msg =~ s/\n\n$/\n/;
    die $msg;
}

# Is the environment variable valid or not?
sub check_env_utf8 {
    my $envvar = $_[0];

    if (exists $ENV{$envvar} and $ENV{$envvar} ne '') {
	if (! decode_utf8($ENV{$envvar})) {
	    warn "$progname warning: environment variable $envvar not UTF-8 encoded; ignoring\n";
	} else {
	    $env{$envvar} = decode_utf8($ENV{$envvar});
	}
    }
}

# vim:ts=4:sw=4:expandtab:tw=80
