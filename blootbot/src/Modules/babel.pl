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

    return unless &loadPerlModule("URI::Escape");

    $lang = $lang_code{$lang};

    my $ua = new LWP::UserAgent;
    $ua->timeout(10);

    my $url = 'http://babelfish.altavista.digital.com/cgi-bin/translate';
    my $req = HTTP::Request->new('POST',$url);
    $req->content_type('application/x-www-form-urlencoded');

    my $tolang = "en_$lang";
    my $toenglish = "${lang}_en";

    if ($direction eq 'to') {
	&main::performStrictReply( translate($phrase, $tolang, $req, $ua) );
	return;
    } elsif ($direction eq 'from') {
	&main::performStrictReply( translate($phrase, $toenglish, $req, $ua) );
	return;
    }

    my $last_english = $phrase;
    my $last_lang;
    my %results = ();
    my $i = 0;
    while ($i++ < 7) {
	last if $results{$phrase}++;
	$last_lang = $phrase = translate($phrase, $tolang, $req, $ua);
	last if $results{$phrase}++;
	$last_english = $phrase = translate($phrase, $toenglish, $req, $ua);
    }

    &main::performStrictReply($last_english);
}

sub translate {
    return '' if $no_babel;
    my ($phrase, $languagepair, $req, $ua) = @_;

    my $urltext = uri_escape($phrase);
    $req->content("urltext=$urltext&lp=$languagepair&doit=done");

    my $res = $ua->request($req);

    my $translated;
    if ($res->is_success) {		# success.
	my $html = $res->content;
	# This method subject to change with the whims of Altavista's design
	# staff.

	$translated =
	  ($html =~ m{<br>
			  \s+
			      <font\ face="arial,\ helvetica">
				  \s*
				      (?:\*\*\s+time\ out\s+\*\*)?
					  \s*
					      ([^<]*)
					      }sx);

	$translated =~ s/\n/ /g;
	$translated =~ s/\s*$//;
    } else {				# failure
	$translated = ":(";
    }

    return $translated;
}

1;
