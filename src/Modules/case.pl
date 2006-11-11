#      case.pl: upper/lower a string
#       Author: Tim Riker
#    Licensing: Artistic License
#      Version: v0.1
#
use strict;

package case;

sub upper {
    my($message) = @_;
    # make it green like an old terminal
    &::performStrictReply("\00303" . uc $message);
}

sub lower {
    my($message) = @_;
    &::performStrictReply(lc $message);
}

1;
