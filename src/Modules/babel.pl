# This program is copyright Jonathan Feinberg 1999.
# This program is distributed under the same terms as infobot.

# Jonathan Feinberg
# jdf@pobox.com
# http://pobox.com/~jdf/

# Version 1.0
# First public release.

package babel;
use strict;

BEGIN {
    # Translate some feasible abbreviations into the ones babelfish
    # expects.
    use vars qw!%lang_code $lang_regex!;
    %lang_code = (
		'fr' => 'fr',
		'sp' => 'es',
		'po' => 'pt',
		'pt' => 'pt',
		'it' => 'it',
		'ge' => 'de',
		'de' => 'de',
		'gr' => 'de',
		'en' => 'en'
	       );

    # Here's how we recognize the language you're asking for.  It looks
    # like RTSL saves you a few keystrokes in #perl, huh?
    $lang_regex = join '|', keys %lang_code;
}

sub babelfish {
    my ($direction, $lang, $phrase) = @_;

    return unless &::loadPerlModule("URI::Escape");
    return unless &::loadPerlModule("LWP::UserAgent");

    $lang = $lang_code{$lang};

    my $ua = new LWP::UserAgent;
    $ua->timeout(10);
    $ua->proxy('http', $::param{'httpProxy'}) if &::IsParam("httpProxy");

    my $url = 'http://babelfish.altavista.com/raging/translate.dyn';
    my $req = HTTP::Request->new('POST',$url);

    $req->content_type('application/x-www-form-urlencoded');

    my $tolang = "en_$lang";
    my $toenglish = "${lang}_en";

    if ($direction eq 'to') {
	my $xlate = translate($phrase, $tolang, $req, $ua);
	&::pSReply($xlate) if ($xlate);
	return;
    } elsif ($direction eq 'from') {
	my $xlate = translate($phrase, $toenglish, $req, $ua);
	&::pSReply($xlate) if ($xlate);
	return;
    }
    &DEBUG("what's this junk?");

    my $last_english = $phrase;
    my $last_lang;
    my %results = ();
    my $i = 0;
    while ($i++ < 7) {
	last if $results{$phrase}++;	# REMOVE!
	$last_lang = $phrase = translate($phrase, $tolang, $req, $ua);
	last if $results{$phrase}++;	# REMOVE!
	$last_english = $phrase = translate($phrase, $toenglish, $req, $ua);
    }

    &::pSReply($last_english);
}

sub translate {
    my ($phrase, $languagepair, $req, $ua) = @_;

    my $urltext = URI::Escape::uri_escape($phrase);
    $req->content("urltext=$urltext&lp=$languagepair&doit=done");

    my $res = $ua->request($req);

    my $translated;
    if ($res->is_success) {		# success.
	my $html = $res->content;
	$html	=~ s/\cM//g;
	$html	=~ s/\n\s*\n/\n/g;
	$html	=~ s/\n/ /g;	# ...

	if ($html =~ /<textarea.*?>(.*?)<\/textarea/si) {
	    $translated = $1;
	    $translated =~ s/^[\n ]|[\n ]$//g;
	} else {
	    &::WARN("failed regex for babelfish.");
	}

    } else {				# failure
	$translated = "FAILURE w/ babelfish";
    }

    $translated	||= "NULL reply from babelfish.";

    return $translated;
}

1;
