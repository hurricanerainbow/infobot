# This program is copyright Jonathan Feinberg 1999.
# This program is distributed under the same terms as infobot.

# Jonathan Feinberg
# jdf@pobox.com
# http://pobox.com/~jdf/

# Version 1.0
# First public release.

# hacked by Tim@Rikers.org to handle new URL and layout

package babel;
use strict;

my $no_babel;

BEGIN {
    eval "use URI::Escape";    # utility functions for encoding the
    if ($@) { $no_babel++};    # babelfish request
    eval "use LWP::UserAgent";
    if ($@) { $no_babel++};
}

BEGIN {
  # Translate some feasible abbreviations into the ones babelfish
  # expects.
    use vars qw!%lang_code $lang_regex!;
    %lang_code = (
                'fr' => 'fr',
                'sp' => 'es',
                'es' => 'es',
                'po' => 'pt',
                'pt' => 'pt',
                'it' => 'it',
                'ge' => 'de',
                'de' => 'de',
                'gr' => 'de',
                'en' => 'en',
                'zh' => 'zh',
                'ja' => 'ja',
                'jp' => 'ja',
                'ko' => 'ko',
                'kr' => 'ko',
                'ru' => 'ru'
               );

  # Here's how we recognize the language you're asking for.  It looks
  # like RTSL saves you a few keystrokes in #perl, huh?
  $lang_regex = join '|', keys %lang_code;
}

sub babelfish {
    return '' if $no_babel;
  my ($from, $to, $phrase) = @_;
  #&main::DEBUG("babelfish($from, $to, $phrase)");

  $from = $lang_code{$from};
  $to = $lang_code{$to};

  my $ua = new LWP::UserAgent;
  $ua->timeout(5);

  my $req =
    HTTP::Request->new('POST', 'http://babelfish.altavista.com/raging/translate.dyn');

# babelfish ignored this, but it SHOULD work
# Accept-Charset: iso-8859-1
#  $req->header('Accept-Charset' => 'iso-8859-1');
#  print $req->header('Accept-Charset');
  $req->content_type('application/x-www-form-urlencoded');

  return translate($phrase, "${from}_${to}", $req, $ua);
}

sub translate {
    return '' if $no_babel;
  my ($phrase, $languagepair, $req, $ua) = @_;
  #&main::DEBUG("translate($phrase, $languagepair, $req, $ua)");

  my $urltext = uri_escape($phrase);
  $req->content("urltext=$urltext&lp=$languagepair");
  #&main::DEBUG("http://babelfish.altavista.com/raging/translate.dyn??urltext=$urltext&lp=$languagepair");

  my $res = $ua->request($req);
  my $translated;

  if ($res->is_success) {
      my $html = $res->content;
      # This method subject to change with the whims of Altavista's design
      # staff.
      $html =~ s/\s+/ /sg;
      #&main::DEBUG("$html\n===============\n");
      # look for the first :< which should be the "To English:<", etc.
      # strip any trailing tags, grab text that follows up to the next tag.
      #my ($translated) = ($html =~ m{:\s*(<[^>]*>\s*)+([^<]*)}sx);
      ($translated) = $html;
      #(undef, $translated) = ($html =~ m{(:\s+(<[^>]*>\s*)+)([^<\s]*)<}sx);

      # Tim@Rikers.org get's frustrated and splits this into steps:
      # 1) remove everything up to the first ':' in the text
      $translated =~ s/.*?:\s*</</s;
      # 2) remove any <attributes> till the first text
      $translated =~ s/(<[^>]*>\s*)*//s;
      # 3) remove the first trailing <attribute> and everything after it
      $translated =~ s/<.*//s;

      # look for contents of first textarea - not anymore cause > 40 char does not get one.
      #my ($translated) = ($html =~ m{<textarea[^>]*>+([^<]*)}sx);
      #&main::DEBUG("\"$translated\"\n===============\n");
#       ($html =~ m{<textarea[^>]*>
#               \s*
#               ([^<]*)
#               }sx);
#         ($html =~ m{<br>
#                         \s+
#                             <font\ face="arial,\ helvetica">
#                                 \s*
#                                     (?:\*\*\s+time\ out\s+\*\*)?
#                                         \s*
#                                             ([^<]*)
#                                             }sx);
      $translated =~ s/\n/ /g;
      $translated =~ s/\s*$//;
      # need a way to do unicode->iso
  } else {
      $translated = ":("; # failure
  }
  &main::pSReply($translated);
}

if (0) {
    if (-t STDIN) {
        #my $result = babel::babelfish('en','sp','hello world');
        #my $result = babel::babelfish('en','sp','The cheese is old and moldy, where is the bathroom?');
        my $result = babel::babelfish('en','gr','doesn\'t seem to translate things longer than 40 characters');
        $result =~ s/; /\n/g;
        print "Babelfish says: \"$result\"\n";
    }
}

1;
