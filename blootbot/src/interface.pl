#
# interface.pl:
#       Author:
#

# use strict;	# TODO

sub whatInterface {
    if (!&IsParam("Interface") or $param{'Interface'} =~ /IRC/) {
	return "IRC";
    } else {
	return "CLI";
    }
}

1;
