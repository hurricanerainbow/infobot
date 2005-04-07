# This program is copyright Jonathan Feinberg 1999.
# This program is distributed under the same terms as infobot.

# Jonathan Feinberg
# jdf@pobox.com
# http://pobox.com/~jdf/

# Version 1.0
# First public release.

# hacked by Tim@Rikers.org to handle new URL and layout

package babelfish;
use strict;

my $no_babelfish;
my $url = 'http://babelfish.av.com/tr';

BEGIN {
    eval "use URI::Escape";    # utility functions for encoding the
    if ($@) { $no_babelfish++};    # babelfish request
    eval "use LWP::UserAgent";
    if ($@) { $no_babelfish++};
}

BEGIN {
  # Translate some feasible abbreviations into the ones babelfish
  # expects.
    use vars qw!%lang_code $lang_regex!;
    %lang_code = (
		'de' => 'de',
		'ge' => 'de',
		'gr' => 'el',
		'el' => 'el',
		'sp' => 'es',
		'es' => 'es',
		'en' => 'en',
		'fr' => 'fr',
		'it' => 'it',
		'ja' => 'ja',
		'jp' => 'ja',
		'ko' => 'ko',
		'kr' => 'ko',
		'nl' => 'nl',
		'po' => 'pt',
		'pt' => 'pt',
		'ru' => 'ru',
		'zh' => 'zh',
		'zt' => 'zt'
	       );

  # Here's how we recognize the language you're asking for.  It looks
  # like RTSL saves you a few keystrokes in #perl, huh?
  $lang_regex = join '|', keys %lang_code;
}

sub babelfishParam {
    return '' if $no_babelfish;
  my ($from, $to, $phrase) = @_;
  &::DEBUG("babelfish($from, $to, $phrase)");

  $from = $lang_code{$from};
  $to = $lang_code{$to};

  my $ua = new LWP::UserAgent;
  $ua->proxy('http', $::param{'httpProxy'}) if (&::IsParam("httpProxy"));
  # Let's pretend
  $ua->agent("Mozilla/5.0 " . $ua->agent);
  $ua->timeout(5);

  my $req = HTTP::Request->new('POST', $url);

# babelfish ignored this, but it SHOULD work
# Accept-Charset: iso-8859-1
#  $req->header('Accept-Charset' => 'iso-8859-1');
#  print $req->header('Accept-Charset');
  $req->header('Accept-Language' => 'en');
  $req->content_type('application/x-www-form-urlencoded');

  return translate($phrase, "${from}_${to}", $req, $ua);
}

sub translate {
    return '' if $no_babelfish;
  my ($phrase, $languagepair, $req, $ua) = @_;
  &::DEBUG("translate($phrase, $languagepair, $req, $ua)");

  my $trtext = uri_escape($phrase);
  $req->content("trtext=$trtext&lp=$languagepair");
  &::DEBUG("$url??trtext=$trtext&lp=$languagepair");

  my $res = $ua->request($req);
  my $translated;

  if ($res->is_success) {
    my $html = $res->content;
    # This method subject to change with the whims of Altavista's design
    # staff.
    ($translated) = $html;

    $translated =~ s/<[^>]*>//sg;
    $translated =~ s/&nbsp;/ /sg;
    $translated =~ s/\s+/ /sg;
    #&::DEBUG("$translated\n===remove <attributes>\n");

    $translated =~ s/\s*Translate again.*//i;
    &::DEBUG("$translated\n===remove after 'Translate again'\n");

    $translated =~ s/[^:]*?:\s*(Help\s*)?//s;
    &::DEBUG("len=" . length($translated) . " $translated\n===remove to first ':', optional Help\n");

    $translated =~ s/\n/ /g;
    # FIXME: should we do unicode->iso (no. use utf8!)
  } else {
    $translated = ":("; # failure
  }
  $translated = "babelfish.pl: result too long, probably an error" if (length($translated) > 700);

  return $translated
}

sub babelfish {
  my ($message) = @_;
  my $babel_lang_regex = "de|ge|gr|el|sp|es|en|fr|it|ja|jp|ko|kr|nl|po|pt|ru|zh|zt";
  if ($message =~ m{
    ($babel_lang_regex)\w*	# from language?
    \s+
    ($babel_lang_regex)\w*	# to language?
    \s*
    (.+)			# The phrase to be translated
  }xoi) {
    &::performStrictReply(&babelfishParam(lc $1, lc $2, lc $3));
  }
  return;
}

if (0) {
    if (-t STDIN) {
	#my $result = babelfish::babelfish('en sp hello world');
	#my $result = babelfish::babelfish('en sp The cheese is old and moldy, where is the bathroom?');
	my $result = babelfish::babelfish('en gr doesn\'t seem to translate things longer than 40 characters');
	$result =~ s/; /\n/g;
	print "Babelfish says: \"$result\"\n";
    }
}

1;
