#
#  Dict.pl: Frontend to dict.org.
#   Author: dms
#  Version: v0.6c (20000924).
#  Created: 19990914.
#  Updates: Copyright (c) 2005 - Tim Riker <Tim@Rikers.org>
#
# see http://luetzschena-stahmeln.de/dictd/
# for a list of dict servers

package Dict;

use IO::Socket;
use strict;

#use vars qw(PF_INET);

# need a specific host||ip.
my $server	= "dict.org";

sub Dict {
    my ($query) = @_;
#    return unless &::loadPerlModule("IO::Socket");
    my $port	= 2628;
    my $proto	= getprotobyname('tcp');
    my @results;
    my $retval;

    for ($query) {
	s/^[\s\t]+//;
	s/[\s\t]+$//;
	s/[\s\t]+/ /;
    }

    # connect.
    # TODO: make strict-safe constants... so we can defer IO::Socket load.
    my $socket	= new IO::Socket;
    socket($socket, PF_INET, SOCK_STREAM, $proto) or return "error: socket: $!";
    eval {
	local $SIG{ALRM} = sub { die "alarm" };
	alarm 10;
	connect($socket, sockaddr_in($port, inet_aton($server))) or die "error: connect: $!";
	alarm 0;
    };

    if ($@) {
	# failure.
	$retval = "i could not get info from $server '$@'";
    } else {				# success.
	$socket->autoflush(1);	# required.

	my $num;
	if ($query =~ s/^(\d+)\s+//) {
	    $num = $1;
	}

	# body.
	push(@results, &Dict_Wordnet($socket,$query));
	push(@results, &Dict_Foldoc($socket,$query));
	push(@results, &Dict_web1913($socket,$query));
	# end.

	print $socket "QUIT\n";
	close $socket;

	&::DEBUG(join(";;\n",@results));
	my $total = scalar @results;

	if ($total == 0) {
	    $num = undef;
	}

	if (defined $num and ($num > $total or $num < 1)) {
	    &::msg($::who, "error: choice in definition is out of range.");
	    return;
	}

	# parse the results.
	if ($total > 1) {
	    if (defined $num) {
		$retval = sprintf("[%d/%d] %s", $num, $total, $results[$num-1]);
	    } else {
		# suggested by larne and others.
		my $prefix = "Dictionary '$query' ";
		$retval = &::formListReply(1, $prefix, @results);
	    }
	} elsif ($total == 1) {
	    $retval = "Dictionary '$query' ".$results[0];
	} else {
	    $retval = "could not find definition for \002$query\002";
	}
    }

    &::performStrictReply($retval);
}

sub Dict_Wordnet {
    my ($socket, $query) = @_;
    my @results;

    &::status("Dict: asking Wordnet.");
    print $socket "DEFINE wn \"$query\"\n";

    my $def		= "";
    my $wordtype	= "";

    while (<$socket>) {
	chop;	# remove \n
	chop;	# remove \r

	&::DEBUG("wordnet '$_'");
	if (/^552 no match/) {
	    # no match.
	    return;
	} elsif (/^250 ok/) {
            # stats.
	    last;
	} elsif ($_ eq ".") {
	    # end of def.
	    push(@results, $def);
	} elsif (/^\s+(\S+ )?(\d+)?: (.*)/) {	# start of sub def.
	    my $text = $3;
	    $def =~ s/\s+$//;
	    #&::DEBUG("def => '$def'.");
	    push(@results, $def)		if ($def ne "");
	    $def = $text;

	    if (0) {	# old non-fLR format.
		$def = "$query $wordtype: $text" if (defined $text);
		$wordtype = substr($1,0,-1)	if (defined $1);
		#&::DEBUG("_ => '$_'.") if (!defined $text);
	    }
	} elsif (/^\s+(.*)/) {
	    s/^\s{2,}/ /;
	    $def	.= $_;
	    $def =~ s/\[.*?\]$//g;
	} else {
	    &::DEBUG("ignored '$_'");
	}
    }

    &::status("Dict: wordnet: found ". scalar(@results) ." defs.");

    return if (!scalar @results);

    return @results;
}

sub Dict_Foldoc {
    my ($socket,$query) = @_;
    my @results;

    &::status("Dict: asking Foldoc.");
    print $socket "DEFINE foldoc \"$query\"\n";

    my $firsttime = 1;
    my $def;
    while (<$socket>) {
	chop;	# remove \n
	chop;	# remove \r

	&::DEBUG("foldoc '$_'");
	if (/^552 /) {
	    # no match
	    return;
	} elsif (/^250 ok/) {
	    #end
	    last;
	} elsif (/^\.$/) {
	    #end of def
	    next if ($def eq "");
	    $def =~ s/^\s+|\s+$//g;	# sub def.
	    push(@results, $def);
	    $def = "";
	    next;
	} elsif (/^\s+(.*)/) {
	    # each line.
	    s/[{}]//g;
	    s/^\s+|\s+$//g;
	    $def .= $_." ";
	} elsif ($_ eq "") {			# sub def separator.
	    if ($firsttime) {
		$firsttime--;
		next;
	    }
	    $def =~ s/^\s+|\s+$//g;	# sub def.
	    $def =~ s/[{}]//g;
	} else {
	    &::DEBUG("ignored '$_'");
	}
    }

    &::status("Dict: foldoc: found ". scalar(@results) ." defs.");

    return if (!scalar @results);
    #pop @results;	# last def is date of entry.

    return @results;
}

sub Dict_web1913 {
    my ($socket,$query) = @_;
    my @results;

    &::status("Dict: asking web1913.");
    print $socket "DEFINE web1913 \"$query\"\n";

    my $string;
    while (<$socket>) {
	# remove \n
	chop;
	# remove \r
	chop;
	&::DEBUG("web1913 '$_'");

	# no match.
	return if /^552/;

	# stats; end of def.
	last if (/^250/);

	# definition and/or retrieval
	next if (/^151/ or /^150/);

	# each line.
	s/^\s+|\s+$//g;

	# sub def separator.
	if ($_ eq "" or $_ =~ /^\.$/) {
	    # sub def.
	    $string =~ s/^\s+|\s+$//g;
	    $string =~ s/[{}]//g;

	    next if ($string eq "");

	    push(@results, $string);
	    $string = "";
	}

	$string .= $_." ";
    }

    &::status("Dict: web1913: found ". scalar(@results) ." defs.");

    return if (!scalar @results);
    # last def is date of entry.
    #pop @results;

    return @results;
}

1;
