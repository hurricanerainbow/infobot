#      case.pl: upper/lower a string
#       Author: Tim Riker
#    Licensing: Artistic License
#      Version: v0.1
#
use strict;

package case;

sub upper {
    my($message) = @_;
    &::performStrictReply(uc $message);
}

sub lower {
    my($message) = @_;
    &::performStrictReply(lc $message);
}

1;
