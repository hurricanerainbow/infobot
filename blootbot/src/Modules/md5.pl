#       md5.pl: md5 a string
#       Author: Tim Riker
#    Licensing: Artistic License
#      Version: v0.1 (20041209)
#
use strict;

package md5;

sub md5 {
    my($message) = @_;
    return unless &::loadPerlModule("Digest::MD5");

#perl -e'use Digest::MD5 qw(md5_hex); print md5_hex("foo\n") . "\n";'

    &::pSReply(&Digest::MD5::md5_hex($message));
}

1;
