# This module is a plugin for WWW::Scraper, and allows one to search
# google, and is released under the terms of the GPL version 2, or any
# later version. See the file README and COPYING for more
# information. Copyright 2002 by Don Armstrong <don@donarmstrong.com>.

# $Id:  $

package DebianBugs;

use warnings;
use strict;

use vars qw($VERSION $DEBUG);

use SOAP::Lite;

$VERSION = q($Rev: $);
$DEBUG ||= 0;

sub bug_info {
    my ($bug_num,$options) = @_;

    $options || = {};

    if ( not $bug_num =~ /^\#?\d+$/ ) {
        warn "Bug is not a number!" and return undef
          if not $options->{return_warnings};
        return "Bug is not a number!";
    }
    $bug_num =~ s/^\#//;
    my $soap = SOAP::Lite->url->('Debbugs/SOAP/1')->
	proxy('http://bugs.debian.org/cgi-bin/soap.cgi');
    $soap->transport->env_proxy();
    my $result = $soap->get_status(bug => $bug_num)->result();
    if (not defined $result) {
	return "No such bug (or some kind of error)";
    }
    my $bug = {};
    $bug->{num} = $result->{bug_num};
    $bug->{title} = $result->{subject};
    $bug->{severity} = $result->{severity};    #Default severity is normal
    # Just leave the leter instead of the whole thing.
    $bug->{severity} =~ s/^(.).+$/$1/;
    $bug->{package} = $result->{package};
    $bug->{reporter} = $result->{submitter};
    $bug->{date} = $result->{date};
    $bug->{tags} = $result->{keywords};
    $bug->{done} = defined $result->{done} and length $result->{done};
    $bug->{merged_with} = $result->{mergedwith};
    # report bug

    my $report = '';
    $report .= 'DONE:' if defined $bug->{done} and $bug->{done};
    $report .= '#'
      . $bug->{num} . ':'
      . uc( $bug->{severity} ) . '['
      . $bug->{package} . '] '
      . $bug->{title};
    $report .= ' (' . $bug->{tags} . ')' if defined $bug->{tags};
    $report .= '; ' . $bug->{date};

    # Avoid reporting so many merged bugs.
    $report .= ' ['
      . join( ',', splice( @{ [ split( /,/, $bug->{merged_with} ) ] }, 0, 3 ) )
      . ']'
      if defined $bug->{merged_with};
    return $report;
}

sub package_bugs($) {

}

1;


__END__

# vim:ts=4:sw=4:expandtab:tw=80
