#
# Files.pl: Open and close, read and probably write files.
#   Author: dms
#  Version: v0.3 (20010120)
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

# File: Irc Servers list.
sub loadIRCServers {
    my ($file)	= $bot_config_dir."/blootbot.servers";
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

1;
