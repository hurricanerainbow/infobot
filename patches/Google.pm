##########################################################
# Google.pm
# by Jim Smyser
# Copyright (C) 1996-1999 by Jim Smyser & USC/ISI
# $Id: Google.pm,v 2.20 2000/07/09 14:29:22 jims Exp $
##########################################################


package WWW::Search::Google;


=head1 NAME

WWW::Search::Google - class for searching Google 


=head1 SYNOPSIS

use WWW::Search;
my $Search = new WWW::Search('Google'); # cAsE matters
my $Query = WWW::Search::escape_query("Where is Jimbo");
$Search->native_query($Query);
while (my $Result = $Search->next_result()) {
print $Result->url, "\n";
}

=head1 DESCRIPTION

This class is a Google specialization of WWW::Search.
It handles making and interpreting Google searches.
F<http://www.google.com>.

This class exports no public interface; all interaction should
be done through L<WWW::Search> objects.

=head1 LINUX SEARCH

For LINUX lovers like me, you can put Googles in a LINUX only search
mode by changing search URL from:

 'search_url' => 'http://www.google.com/search',

to:

 'search_url' => 'http://www.google.com/linux',

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.

=head1 HOW DOES IT WORK?

C<native_setup_search> is called (from C<WWW::Search::setup_search>)
before we do anything.  It initializes our private variables (which
all begin with underscore) and sets up a URL to the first results
page in C<{_next_url}>.

C<native_retrieve_some> is called (from C<WWW::Search::retrieve_some>)
whenever more hits are needed.  It calls C<WWW::Search::http_request>
to fetch the page specified by C<{_next_url}>.
It then parses this page, appending any search hits it finds to 
C<{cache}>.  If it finds a ``next'' button in the text,
it sets C<{_next_url}> to point to the page for the next
set of results, otherwise it sets it to undef to indicate we''re done.


=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 

=head1 AUTHOR

This backend is written and maintained/supported by Jim Smyser.
<jsmyser@bigfoot.com>

=head1 BUGS

Google is not an easy search engine to parse in that it is capable 
of altering it's output ever so slightly on different search terms.
There may be new slight results output the author has not yet seen that
will pop at any given time for certain searches. So, if you think you see
a bug keep the above in mind and send me the search words you used so I
may code for any new variations.

=head1 CHANGES

2.21.1
Parsing update from Tim Riker <Tim@Rikers.org>

2.21
Minor code correction for empty returned titles

2.20
Forgot to add new next url regex in 2.19!

2.19
Regex work on some search results url's that has changed. Number found 
return should be right now.

2.17
Insert url as a title when no title is found. 

2.13
New regexp to parse newly found results format with certain search terms.

2.10
removed warning on absence of description; new test case

2.09
Google NOW returning url and title on one line.

2.07
Added a new parsing routine for yet another found result line.
Added a substitute for whacky url links some queries can produce.
Added Kingpin's new hash_to_cgi_string() 10/12/99

2.06
Fixed missing links / regexp crap.

2.05
Matching overhaul to get the code parsing right due to multiple 
tags being used by google on the hit lines. 9/25/99

2.02
Last Minute description changes  7/13/99

2.01
New test mechanism  7/13/99

1.00
First release  7/11/99

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.


=cut
#'
          
          
#####################################################################
          
require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '2.21';

$MAINTAINER = 'Jim Smyser <jsmyser@bigfoot.com>';
$TEST_CASES = <<"ENDTESTCASES";
# Google looks for partial words it can find results for so it will end up finding "Bogus" pages.
&test('Google', '$MAINTAINER', 'zero', '4036e7757s5', \$TEST_EXACTLY);
&test('Google', '$MAINTAINER', 'one_page', '+LS'.'AM +rep'.'lication', \$TEST_RANGE, 2,99);
&test('Google', '$MAINTAINER', 'multi', 'dir'.'ty ha'.'rr'.'y bimbo', \$TEST_GREATER_THAN, 101);
ENDTESTCASES
          
use Carp ();
use WWW::Search(qw(generic_option strip_tags));
require WWW::SearchResult;
          
          
sub undef_to_emptystring {
return defined($_[0]) ? $_[0] : "";
}
# private
sub native_setup_search
    {
     my($self, $native_query, $native_options_ref) = @_;
     $self->user_agent('user');
     $self->{_next_to_retrieve} = 0;
     $self->{'_num_hits'} = 100;
         if (!defined($self->{_options})) {
         $self->{_options} = {
         'search_url' => 'http://www.google.com/search',
         'num' => $self->{'_num_hits'},
         };
         };
     my($options_ref) = $self->{_options};
     if (defined($native_options_ref)) {
     # Copy in new options.
     foreach (keys %$native_options_ref) {
     $options_ref->{$_} = $native_options_ref->{$_};
     };
     };
     # Process the options.
     my($options) = '';
     foreach (keys %$options_ref) {
     # printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
     next if (generic_option($_));
     $options .= $_ . '=' . $options_ref->{$_} . '&';
     };
     $self->{_debug} = $options_ref->{'search_debug'};
     $self->{_debug} = 2 if ($options_ref->{'search_parse_debug'});
     $self->{_debug} = 0 if (!defined($self->{_debug}));
               
     # Finally figure out the url.
     $self->{_base_url} =
     $self->{_next_url} =
     $self->{_options}{'search_url'} .
     "?" . $options .
     "q=" . $native_query;
     }
          
# private
sub begin_new_hit {
     my($self) = shift;
     my($old_hit) = shift;
     my($old_raw) = shift;
     if (defined($old_hit)) {
     $old_hit->raw($old_raw) if (defined($old_raw));
     push(@{$self->{cache}}, $old_hit);
     };
     return (new WWW::SearchResult, '');
     }
sub native_retrieve_some {
     my ($self) = @_;
     # fast exit if already done
     return undef if (!defined($self->{_next_url}));
     # get some
     print STDERR "Fetching " . $self->{_next_url} . "\n" if ($self->{_debug});
     my($response) = $self->http_request('GET', $self->{_next_url});
     $self->{response} = $response;
     if (!$response->is_success) {
     return undef;
     };

     # parse the output
     my($HEADER, $HITS, $TRAILER, $POST_NEXT) = (1..10);
     my($hits_found) = 0;
     my($state) = ($HEADER);
     my($hit) = undef;
     my($raw) = '';
     foreach ($self->split_lines($response->content())) {
     next if m@^$@; # short circuit for blank lines

  if ($state == $HEADER && m/about <b>([\d,]+)<\/b>/) 
     {
     my($n) = $1;
     $self->approximate_result_count($n);
     print STDERR "Found Total: $n\n" ;
     $state = $HITS;
     } 
  if ($state == $HITS &&
     m|<p><a href=([^\>]*)\>(.*?)</a\><br\>|i) {
     my ($url, $title) = ($1,$2);
     ($hit, $raw) = $self->begin_new_hit($hit, $raw);
     print STDERR "**Found HIT0 Line** $url - $title\n" if ($self->{_debug});
     $raw .= $_;
     $url =~ s/(>.*)//g;
     $hit->add_url(strip_tags($url));
     $hits_found++;
     $title = "No Title" if ($title =~ /^\s+/);
     $hit->title(strip_tags($title));
     $state = $HITS;
     } 
  elsif ($state == $HITS &&
     m|<a href=(.*)\>(.*?)</a><font size=-1><br><font color=green><.*?>|i) {
     my ($url, $title) = ($1,$2);
     ($hit, $raw) = $self->begin_new_hit($hit, $raw);
     print STDERR "**Found HIT1 Line**\n" if ($self->{_debug});
     $raw .= $_;
     $url =~ s/(>.*)//g;
     $hit->add_url(strip_tags($url));
     $hits_found++;
     $title = "No Title" if ($title =~ /^\s+/);
     $hit->title(strip_tags($title));
     $state = $HITS;
     } 
  elsif ($state == $HITS &&
     m@^<p><a href=/url\?sa=U&start=\d+&q=([^<]+)\&.*?>(.*)</a><font size=-1><br>(.*)@i ||
     m@^<p><a href=([^<]+)>(.*)</a>.*?<font size=-1><br>(.*)@i)
     {
     ($hit, $raw) = $self->begin_new_hit($hit, $raw);
     print STDERR "**Found HIT2 Line**\n" if ($self->{_debug});
     my ($url, $title) = ($1,$2);
     $mDesc = $3;
     $url =~ s/\/url\?sa=\w&start=\d+&q=//g;
     $url =~ s/&(.*)//g;
     $url =~ s/(>.*)//g;
     $raw .= $_;
     $hit->add_url(strip_tags($url));
     $hits_found++;
     $title = "No Title" if ($title =~ /^\s+/);
     $hit->title(strip_tags($title));
     $mDesc =~ s/<.*?>//g;
     $mDesc =  $mDesc . '<br>' if not $mDesc =~ m@<br>@;
     $hit->description($mDesc) if (defined($hit));
     $state = $HITS;
     } 
  elsif ($state == $HITS && m@^(\.\.(.+))@i) 
     {
     print STDERR "**Parsing Description Line**\n" if ($self->{_debug});
     $raw .= $_;
     $sDesc = $1;
     $sDesc ||= '';
     $sDesc =~ s/<.*?>//g;
     $sDesc = $mDesc . $sDesc;
     $hit->description($sDesc) if $sDesc =~ m@^\.@;
     $sDesc = '';
     $state = $HITS;
     } 
  elsif ($state == $HITS && m@<div class=nav>@i) 
     {
     ($hit, $raw) = $self->begin_new_hit($hit, $raw);
     print STDERR "**Found Last Line**\n" if ($self->{_debug});
     # end of hits
     $state = $TRAILER;
     } 
  elsif ($state == $TRAILER && 
     m|<a href=([^<]+)><IMG SRC=/nav_next.gif.*?>.*?|i) 
     {
     my($relative_url) = $1;
     print STDERR "**Fetching >>Next<< Page**\n" if ($self->{_debug});
     $self->{_next_url} = 'http://www.google.com' . $relative_url;
     $state = $POST_NEXT;
     } else {
     };
     };
  if ($state != $POST_NEXT) {
     # No "Next" Tag
     $self->{_next_url} = undef;
     if ($state == $HITS) {
     $self->begin_new_hit($hit, $raw);
     };
     $self->{_next_url} = undef;
     };
     # ZZZzzzzZZZZzzzzzzZZZZZZzzz
     $self->user_agent_delay if (defined($self->{_next_url}));
     return $hits_found;
     }
1;

