#
# Files.pl: Open and close, read and probably write files.
#   Author: dms
#  Version: v0.2 (2000502)
#  Created: 19991221
#

if (&IsParam("useStrict")) { use strict; }

# File: Language support.
sub loadLang {
    my ($file) = @_;
    my $langCount = 0;
    my $replyName;

    if (!open(FILE, $file)) {
	&ERROR("FAILED loadLang ($file): $!");
	exit 0;
    }

    undef %lang;		# for rehash.

    while (<FILE>) {
	chop;
	if ($_ eq "" || /^#/) {
	    undef $replyName;
	    next;
	}

	if (!/^\s/) {
	    $replyName = $_;
	    next;
	}

	s/^[\s\t]+//g;
	if (!$replyName) {
	    &status("loadLang: bad line ('$_')");
	    next;
	}

	$lang{$replyName}{$_} = 1;
	$langCount++;
    }
    close FILE;

    $file =~ s/^.*\///;
    &status("Loaded lang $file ($langCount items)");
}

# File: Ignore list.
sub loadIgnore {
    my ($file)	= @_;
    %ignoreList	= ();

    if (!open(FILE, $file)) {
	&ERROR("FAILED loadIgnore ($file): $!");
	return;
    }

    my $count = 0;
    while (<FILE>) {
	chomp;
	next if /^\s*\#/;
	next unless /\S/;

	if (/^(\S+)[\t\s]+(\S+)([\t\s]+.*)?$/) {
	    $ignoreList{$2} = 1;
	    $count++;
	}
    }
    close FILE;

    $file =~ s/^.*\///;
    &status("Loaded ignore $file ($count masks)");
}

# File: Irc Servers list.
sub loadIRCServers {
    my ($file) = @_;
    @ircServers = ();
    %ircPort = ();

    if (!open(FILE, $file)) {
	&ERROR("FAILED loadIRCServers ($file): $!");
	exit 0;
    }

    while (<FILE>) {
	chop;
	next if /^\s*$/;
	next if /^[\#\[ ]/;

	if (/^(\S+)(:(\d+))?$/) {
	    push(@ircServers,$1);
	    $ircPort{$1} = ($3 || 6667);
	} else {
	    &status("loadIRCServers: invalid line => '$_'.");
	}
    }
    close FILE;

    $file =~ s/^.*\///;
    &status("Loaded ircServers $file (". scalar(@ircServers) ." servers)");
}

# File: User List.
sub loadUsers {
    my ($file) = @_;
    %userList = ();	# clear it.

    if (!open(FILE, $file)) {
	&ERROR("FAILED loadUsers ($file): $!");
	exit 0;
    }

    my $userName;

    while (<FILE>) {
	next if /^\s*$/;
	next if /^#/;

	if (/^UserEntry\s+(.+?)\s/) {
	    $userName = $1;
	    if (/\s*\{\s*/) {
		while (<FILE>) {
		    if (/^\s*(\w+)\s+(.+);$/) {
			my ($opt,$val) = ($1,$2);

			$opt =~ tr/A-Z/a-z/;
			$val =~ s/\"//g;
			$val =~ s/\+// if ($opt =~ /^flags$/i);

			if ($opt =~ /^mask$/i) {
			    $userList{$userName}{$opt}{$val} = 1;
			} else {
			    $userList{$userName}{$opt} = $val;
			}
		    } elsif (/^\s*\}\s*$/) {
			last;
		    }
		}
	    } else {
		&status("parse error: User Entry $userName without right brace");
	    }
	}
    }
    close FILE;

    return unless (&IsParam("VERBOSITY"));

    $file =~ s/^.*\///;
    &status("Loaded userlist $file (". scalar(keys %userList) ." users)");
    foreach $userName (keys %userList) {
	&status("  $userName:");
	&status("    flags: +$userList{$userName}{'flags'}");

	foreach (keys %{$userList{$userName}{'mask'}}) {
	    &status("    hostmask: $_");
	}
    }
}

1;
