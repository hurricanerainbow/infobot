##########################################################
# Google.pm
# by Jim Smyser
# Copyright (C) 1996-1999 by Jim Smyser & USC/ISI
# $Id: Google.pm,v 1.1.1.1 2000/07/27 16:10:23 blootbot Exp $
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

Googles returns 100 Hits per page. Custom Linux Only search capable.

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

=head1 BUGS

2.07 now parses for most of what Google produces, but not all.
Because Google does not produce universial formatting for all
results it produces, there are undoublty a few line formats yet 
uncovered by the author. Different search terms creates various
differing format out puts for each line of results. Example,
searching for "visual basic" will create whacky url links,
whereas searching for "Visual C++" does not. It is a parsing
nitemare really! If you think you uncovered a BUG just remember
the above comments!  

With the above said, this back-end will produce proper formated
results for 96+% of what it is asked to produce. Your milage
will vary.

=head1 AUTHOR

This backend is maintained and supported by Jim Smyser.
<jsmyser@bigfoot.com>

=head1 BUGS

2.09 seems now to parse all hits with the new format change so there really shouldn't be
any like there were with 2.08. 

=head1 VERSION HISTORY

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
$VERSION = '2.10';

$MAINTAINER = 'Jim Smyser <jsmyser@bigfoot.com>';
$TEST_CASES = <<"ENDTESTCASES";
# Google looks for partial words it can find results for so it will end up finding "Bogus" pages.
&test('Google', '$MAINTAINER', 'zero', '4036e7757s5', \$TEST_EXACTLY);
&test('Google', '$MAINTAINER', 'one_page', '+LS'.'AM +rep'.'lication', \$TEST_RANGE, 2,99);
&test('Google', '$MAINTAINER', 'multi', 'dir'.'ty ha'.'rr'.'y bimbo', \$TEST_GREATER_THAN, 101);
ENDTESTCASES

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;

sub native_setup_search {
   my($self, $native_query, $native_options_ref) = @_;
   $self->{_debug} = $native_options_ref->{'search_debug'};
   $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
   $self->{_debug} = 0 if (!defined($self->{_debug}));
   $self->{agent_e_mail} = 'jsmyser@bigfoot.com';
   $self->user_agent('user');
   $self->{_next_to_retrieve} = 1;
   $self->{'_num_hits'} = 0;
   if (!defined($self->{_options})) {
     $self->{'search_base_url'} = 'http://www.google.com';
     $self->{_options} = {
         'search_url' => 'http://www.google.com/search',
         'num' => '100',
         'q' => $native_query,
         };
         }
   my $options_ref = $self->{_options};
   if (defined($native_options_ref)) 
     {
     # Copy in new options.
     foreach (keys %$native_options_ref) 
     {
     $options_ref->{$_} = $native_options_ref->{$_};
     } # foreach
     } # if
   # Process the options.
   my($options) = '';
   foreach (sort keys %$options_ref) 
     {
     # printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
     next if (generic_option($_));
     $options .= $_ . '=' . $options_ref->{$_} . '&';
     }
   chop $options;
   # Finally figure out the url.
   $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $self->hash_to_cgi_string($self->{_options});
   } # native_setup_search
 
# private
sub native_retrieve_some
   {
   my ($self) = @_;
   print STDERR "**Google::native_retrieve_some()**\n" if $self->{_debug};
   # Fast exit if already done:
   return undef if (!defined($self->{_next_url}));
   
   # If this is not the first page of results, sleep so as to not
   # overload the server:
   $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};
   
   # Get some if were not already scoring somewhere else:
   print STDERR "*Sending request (",$self->{_next_url},")\n" if $self->{_debug};
   my($response) = $self->http_request('GET', $self->{_next_url});
   $self->{response} = $response;
   if (!$response->is_success) 
     {
     return undef;
     }
   $self->{'_next_url'} = undef;
   print STDERR "**Response\n" if $self->{_debug};

   # parse the output
   my ($HEADER, $START, $HITS, $NEXT) = qw(HE HI ST NX);
   my $hits_found = 0;
   my $state = $HEADER;
   my $hit = ();
   foreach ($self->split_lines($response->content()))
      {
      next if m@^$@; # short circuit for blank lines
      print STDERR " $state ===$_=== " if 2 <= $self->{'_debug'};
  if (m|<b>(\d+)</b></font> matches|i) {
      print STDERR "**Found Header Count**\n" if ($self->{_debug});
      $self->approximate_result_count($1);
      $state = $START;
      # set-up attempting the tricky task of 
      # fetching the very first HIT line
      } 
  elsif ($state eq $START && m|Search took|i) 
      {
      print STDERR "**Found Start Line**\n" if ($self->{_debug});
      $state = $HITS;
      # Attempt to pull the very first hit line
      } 
  if ($state eq $HITS) {
      print "\n**state == HITS**\n" if 2 <= $self->{_debug};
  }
  if ($state eq $HITS && m@^<p><a href=([^<]+)>(.*)</a>@i)
      {
      print "**Found HIT**\n" if 2 <= $self->{_debug};
      my ($url, $title) = ($1,$2);
      if (defined($hit)) 
      {
      push(@{$self->{cache}}, $hit);
      };
      $hit = new WWW::SearchResult;
      # some queries *can* create internal junk in the url link
      # remove them! 
      $url =~ s/\/url\?sa=U&start=\d+&q=//g;
      $url =~ s/\&exp\=OneBoxNews //g;		# ~20000510.
      $url =~ s/\&e\=110 //g;			# -20000528.
      $hits_found++;
      $hit->add_url($url);
      $hit->title($title);
      $state = $HITS;
      } 
  if ($state eq $HITS && m@^<font size=-1><br>(.*)@i) 
      {
      print "**Found First Description**\n" if 2 <= $self->{_debug};
      $mDesc = $1; 
      if (not $mDesc =~ m@&nbsp;@)
      { 
      $mDesc =~ s/<.*?>//g; 
      $mDesc =  $mDesc . '<br>' if not $mDesc =~ m@<br>@;
      $hit->description($mDesc); 
      $state = $HITS;
      }
      } 
  elsif ($state eq $HITS && 
           m@^(\.(.+))@i ||
           m@^<br><font color=green>(.*)\s@i) { 
      print "**Found Second Description**\n" if 2 <= $self->{_debug};
      $sDesc = $1; 
      $sDesc ||= '';
      $sDesc = $mDesc . $sDesc if (defined $mDesc);
      $hit->description($sDesc) if (defined $hit and $sDesc ne '');
      $sDesc ='';
      $state = $HITS;
      } 
   elsif ($state eq $HITS && 
      m|<a href=([^<]+)><IMG SRC=/nav_next.gif.*?><br><.*?>.*?</A>|i) {
      my $nexturl = $self->{'_next_url'};
      if (defined $nexturl) {
	print STDERR "**Fetching Next URL-> ", $nexturl, "\n" if 2 <= $self->{_debug};
      } else {
	print STDERR "**Fetching Next URL-> UNDEF\n" if 2 <= $self->{_debug};
      }
	
      my $iURL = $1;
      $self->{'_next_url'} = $self->{'search_base_url'} . $iURL;
      } 
    else 
      {
      print STDERR "**Nothing matched.**\n" if 2 <= $self->{_debug};
      }
      } 
    if (defined($hit)) 
      {
      push(@{$self->{cache}}, $hit);
      } 
      return $hits_found;
      } # native_retrieve_some
1;  
