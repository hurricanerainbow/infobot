# This program is distributed under the same terms as blootbot.

package wikipedia;
use strict;

my $missing;
my $wikipedia_base_url = 'http://www.wikipedia.org/wiki/';
my $wikipedia_search_url = $wikipedia_base_url . 'Special:Search?';
my $wikipedia_export_url = $wikipedia_base_url . 'Special:Export/';

BEGIN {
  # utility functions for encoding the wikipedia request
  eval "use URI::Escape";
  if ($@) {
    $missing++;
  }

  eval "use LWP::UserAgent";
  if ($@) {
    $missing++;
  }

  eval "use HTML::Entities";
  if ($@) {
    $missing++;
  }

}

sub wikipedia {
  return '' if $missing;
  my ($phrase) = @_;
  &main::DEBUG("wikipedia($phrase)");

  my $ua = new LWP::UserAgent;
  $ua->proxy('http', $::param{'httpProxy'}) if (&::IsParam("httpProxy"));
  # Let's pretend
  $ua->agent("Mozilla/5.0 " . $ua->agent);
  $ua->timeout(5);

  # chop ? from the end
  $phrase =~ s/\?$//;
  # convert phrase to wikipedia conventions
  $phrase = uri_escape($phrase);
  $phrase =~ s/%20/+/g;

  # using the search form will make the request case-insensitive
  # HEAD will follow redirects, catching the first mode of redirects
  # that wikipedia uses
  my $url = $wikipedia_search_url . 'search=' . $phrase . '&go=Go';
  my $req = HTTP::Request->new('HEAD', $url);
  $req->header('Accept-Language' => 'en');
  # &main::DEBUG($url);

  my $res = $ua->request($req);
  # &main::DEBUG($res->code);

  if ($res->is_success) {
    # we have been redirected somewhere
    # (either content or the generic Search form)
    # let's find the title of the article
    $url = $res->request->uri;
    $phrase = $url;
    $phrase =~ s/.*\/wiki\///;

    if ($res->code == '200' and $url !~ m/Special:Search/ ) {
      # we hit content, let's retrieve it
      my $text = wikipedia_get_text($phrase);

      # filtering unprintables
      $text =~ s/[[:cntrl:]]//g;
      # filtering headings
      $text =~ s/==+[^=]*=+//g;
      # filtering wikipedia tables
      &main::DEBUG("START:\n" . $text . " :END");
      $text =~ s/\{\|[^}]+\|\}//g;
      # some people cannot live without HTML tags, even in a wiki
      # $text =~ s/&lt;div.*&gt;//gi;
      # $text =~ s/&lt;!--.*&gt;//gi;
      # $text =~ s/<[^>]*>//g;
      # or HTML entities
      $text =~ s/&amp;/&/g;
      decode_entities($text);
      # or tags, again
      $text =~ s/<[^>]*>//g;
      #$text =~ s/[&#]+[0-9a-z]+;//gi;
      # filter wikipedia tags: [[abc: def]]
      $text =~ s/\[\[[[:alpha:]]*:[^]]*\]\]//gi;
      # {{abc}}:tag
      $text =~ s/\{\{[[:alpha:]]+\}\}:[^\s]+//gi;
      # {{abc}}
      $text =~ s/\{\{[[:alpha:]]+\}\}//gi;
      # unescape quotes
      $text =~ s/'''/'/g;
      $text =~ s/''/"/g;
      # filter wikipedia links: [[tag|link]] -> link
      $text =~ s/\[\[[^]]+\|([^]]+)\]\]/$1/g;
      # [[link]] -> link
      $text =~ s/\[\[([^]]+)\]\]/$1/g;
      # shrink whitespace
      $text =~ s/[[:space:]]+/ /g;
      # chop leading whitespace
      $text =~ s/^ //g;

      # shorten article to first one or two sentences
#      $text = substr($text, 0, 330);
#      $text =~ s/(.+)\.([^.]*)$/$1./g;

      &main::pSReply("At " . $url . " (URL), Wikipedia explains: " . $text);
    }
  }
}

sub wikipedia_get_text {
  return '' if $missing;
  my ($article) = @_;
  &main::DEBUG("wikipedia_get_text($article)");

  my $ua = new LWP::UserAgent;
  $ua->proxy('http', $::param{'httpProxy'}) if (&::IsParam("httpProxy"));
  # Let's pretend
  $ua->agent("Mozilla/5.0 " . $ua->agent);
  $ua->timeout(5);

  my $req = HTTP::Request->new('GET', $wikipedia_export_url .
			       $article);
  $req->header('Accept-Language' => 'en');
  $req->header('Accept-Charset' => 'utf-8');

  my $res = $ua->request($req);
  my ($title, $redirect, $text);
  # &main::DEBUG($res->code);

  if ($res->is_success) {
    if ($res->code == '200' ) {
      foreach (split(/\n/, $res->as_string)) {
	if (/<title>(.*?)<\/title>/) {
	  $title = $1;
	  $title =~ s/&amp\;/&/g;
	} elsif (/#REDIRECT\s*\[\[(.*?)\]\]/) {
	  $redirect = $1;
	  $redirect =~ tr/ /_/;
	  last;
	} elsif (/<text>(.*)/) {
	  $text = $1;
	} elsif (/(.*)<\/text>/) {
	  $text = $text . " " . $1;
	  last;
	} elsif ($text) {
	  $text = $text . " " . $_;
	}
      }
      if (!$redirect and !$text) {
	return;
      }
      return ($text or wikipedia_get_text($redirect))
    }
  }

}

1;
