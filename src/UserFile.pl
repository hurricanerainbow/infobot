#
# UserFile.pl: Dynamic userfile loader
#      Author: dms
#     Version: v0.1 (20000822)
#     Created: 20000822
#      Status: NOT WORKING YET
#
#####
# TODO: major overhaul to support dynamic userfile.
#	support ignore in this file aswell.
#####

if (&IsParam("useStrict")) { use strict; }

# File: User List.
sub NEWloadUsers {
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
