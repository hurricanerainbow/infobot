#
#  DebianExtra.pl: Extra stuff for debian
#          Author: dms
#         Version: v0.1 (20000520)
#         Created: 20000520
#

use strict;

package DebianExtra;

sub Parse {
    my ($args) = @_;
    my ($msg)  = '';

    #&::DEBUG("DebianExtra: $args\n");
    if ( !defined $args or $args =~ /^$/ ) {
        &debianBugs();
    }

    if ( $args =~ /^\#?(\d+)$/ ) {

        # package number:
        $msg = &do_id($args);
    }
    elsif ( $args =~ /^(\S+\@\S+)$/ ) {

        # package email maintainer.
        $msg = &do_email($args);
    }
    elsif ( $args =~ /^(\S+)$/ ) {

        # package name.
        $msg = &do_pkg($args);
    }
    else {

        # invalid.
        $msg = "error: could not parse $args";
    }
    &::performStrictReply($msg);
}

sub debianBugs {
    my @results = &::getURL("http://master.debian.org/~wakkerma/bugs");
    my ( $date, $rcbugs, $remove );
    my ( $bugs_closed, $bugs_opened ) = ( 0, 0 );

    if ( scalar @results ) {
        foreach (@results) {
            s/<.*?>//g;
            $date   = $1 if (/status at (.*)\s*$/);
            $rcbugs = $1 if (/bugs: (\d+)/);
            $remove = $1 if (/REMOVE\S+ (\d+)\s*$/);
            if (/^(\d+) r\S+ b\S+ w\S+ c\S+ a\S+ (\d+)/) {
                $bugs_closed = $1;
                $bugs_opened = $2;
            }
        }
        my $xtxt =
          ( $bugs_closed >= $bugs_opened )
          ? "It's good to see "
          : "Oh no, the bug count is rising -- ";

        &::performStrictReply(
                "Debian bugs statistics, last updated on $date... "
              . "There are \002$rcbugs\002 release-critical bugs;  $xtxt"
              . "\002$bugs_closed\002 bugs closed, opening \002$bugs_opened\002 bugs.  "
              . "About \002$remove\002 packages will be removed." );
    }
    else {
        &::msg( $::who, "Couldn't retrieve data for debian bug stats." );
    }
}

use SOAP::Lite;

sub do_id($) {
    my ($bug_num,$options) = @_;

    $options ||= {};

    if ( not $bug_num =~ /^\#?\d+$/ ) {
        warn "Bug is not a number!" and return undef
          if not $options->{return_warnings};
        return "Bug is not a number!";
    }
    $bug_num =~ s/^\#//;
    my $soap = SOAP::Lite->uri('Debbugs/SOAP/1')->
	proxy('http://bugs.debian.org/cgi-bin/soap.cgi');
    $soap->transport->env_proxy();
    my $temp = $soap->get_status($bug_num);
    use Data::Dumper;
    # enabling this will cause amazing amounts of output
    # &::DEBUG(Dumper($temp));
    if ($temp->fault) {
	return "Some failure (".$temp->fault->{faultstring}.")";
    }
    my $result = $temp->result();
    &::DEBUG(Dumper($result));
    if (not defined $result) {
	return "No such bug (or some kind of error)";
    }
    ($result) = values %{$result};
    my $bug = {};
    $bug->{num} = $result->{bug_num};
    $bug->{title} = $result->{subject};
    $bug->{severity} = $result->{severity};    #Default severity is normal
    # Just leave the leter instead of the whole thing.
    $bug->{severity} =~ s/^(.).+$/$1/;
    $bug->{package} = $result->{package};
    $bug->{reporter} = $result->{submitter};
    use POSIX;
    $bug->{date} = POSIX::strftime(q(%a, %d %b %Y %H:%M:%S UTC),gmtime($result->{date}));
    $bug->{tags} = $result->{keywords};
    $bug->{done} = defined $result->{done} && length($result->{done}) > 0;
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

sub old_do_id {
    my ($num) = @_;
    my $url = "http://bugs.debian.org/$num";

    # FIXME
    return "do_id not supported yet.";
}

sub do_email {
    my ($email) = @_;
    my $url = "http://bugs.debian.org/$email";

    # FIXME
    return "do_email not supported yet.";

    my @results = &::getURL($url);
    foreach (@results) {
        &::DEBUG("do_email: $_");
    }
}

sub do_pkg {
    my ($pkg) = @_;
    my $url = "http://bugs.debian.org/$pkg";

    # FIXME
    return "do_pkg not supported yet.";

    my @results = &::getURL($url);
    foreach (@results) {
        &::DEBUG("do_pkg: $_");
    }
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
