# turns english text into piglatin
# Copyright (c) 2005 Tim Riker <Tim@Rikers.org>

use strict;
use warnings;

package piglatin;

sub piglatin
{
  my ($text) = @_;
  my $piglatin;
  my $suffix = 'ay';

  # FIXME: does not handle:
  #  punctuation and hyphens
  #  y as vowel "style" -> "ylestay"
  #  contractions
  for my $word (split /\s+/, $text) {
    my $pigword;
    if ($word =~ /^(qu)(.*)/ ) {
      $pigword = "$2$1$suffix";
    } elsif ($word =~ /^(Qu)(.)(.*)/ ) {
      $pigword = uc($2) . $3 . lc($1) . $suffix;
    } elsif ($word =~ /^([bcdfghjklmnpqrstvwxyz]+)(.*)/ ) {
      $pigword = "$2$1$suffix";
    } elsif ($word =~ /^([BCDFGHJKLMNPQRSTVWXYZ])([bcdfghjklmnpqrstvwxyz]*)([aeiouy])(.*)/ ) {
      $pigword = uc($3) . $4 . lc($1) . $2 . $suffix;
    } else {
      $pigword = $word . 'w' . $suffix;
    }
    $piglatin .= " $pigword";
  }
  &::performStrictReply($piglatin||'failed');
}

1;
