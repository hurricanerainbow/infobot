#
# logger.pl: logger functions!
#    Author: dms
#   Version: v0.3 (20000731)
#  FVersion: 19991205
#      NOTE: Based on code by Kevin Lenzo & Patrick Cole  (c) 1997
#

use strict;

use vars qw($logDate $loggingstatus $statcount $bot_pid
	    $statcountfix $addressed $logcount $logtime);
use vars qw(@backlog);
use vars qw(%param %file);

require 5.001;

$logtime	= time();

my %attributes = (
	'clear'      => 0,
	'reset'      => 0,
	'bold'       => 1,
	'underline'  => 4,
	'underscore' => 4,
	'blink'	     => 5,
	'reverse'    => 7,
	'concealed'  => 8,
	'black'      => 30,	'on_black'   => 40,
	'red'        => 31,	'on_red'     => 41,
	'green'      => 32,	'on_green'   => 42,
	'yellow'     => 33,	'on_yellow'  => 43,
	'blue'       => 34,	'on_blue'    => 44,
	'magenta'    => 35,	'on_magenta' => 45,
	'cyan'       => 36,	'on_cyan'    => 46,
	'white'      => 37,	'on_white'   => 47
);

use vars qw($b_black $_black $b_red $_red $b_green $_green
	    $b_yellow $_yellow $b_blue $_blue $b_magenta $_magenta
	    $b_cyan $_cyan $b_white $_white $_reset $_bold $ob $b);

$b_black 	= cl('bold black');	$_black		= cl('black');
$b_red		= cl('bold red');	$_red		= cl('red');
$b_green	= cl('bold green');	$_green		= cl('green');
$b_yellow	= cl('bold yellow');	$_yellow	= cl('yellow');
$b_blue		= cl('bold blue');	$_blue		= cl('blue');
$b_magenta	= cl('bold magenta');	$_magenta	= cl('magenta');
$b_cyan		= cl('bold cyan');	$_cyan		= cl('cyan');
$b_white	= cl('bold white');	$_white		= cl('white');
$_reset		= cl('reset');		$_bold		= cl('bold');
$ob		= cl('reset');		$b		= cl('bold');

############################################################################
# Implementation (attribute string form)
############################################################################

# Return the escape code for a given set of color attributes.
sub cl {
    my @codes = map { split } @_;
    my $attribute = '';
    foreach (@codes) {
	$_ = lc $_;
	unless (defined $attributes{$_}) { die "Invalid attribute name $_" }
	$attribute .= $attributes{$_} . ';';
    }
    chop $attribute;
    ($attribute ne '') ? "\e[${attribute}m" : undef;
}

# logging support.
sub openLog {
    return unless (&IsParam("logfile"));
    $file{log} = $param{'logfile'};

    if (&IsParam("logType") and $param{'logType'} =~ /DAILY/i) {
	my ($day,$month,$year) = (localtime(time()))[3,4,5];
	$logDate = sprintf("%04d%02d%02d",$year+1900,$month+1,$day);
	$file{log} .= "-".$logDate;
    }

    if (open(LOG, ">>$file{log}")) {
	&status("Opened logfile $file{log}.");
	LOG->autoflush(1);
	$loggingstatus = 1;
    } else {
	&status("cannot open logfile $file{log}; disabling.");
	$loggingstatus = 0;
    }
}

sub closeLog {
    # lame fix for paramlogfile.
    return unless (&IsParam("logfile"));
    return unless ($loggingstatus);

    $loggingstatus = 0;
    &status("Closed logfile ($file{log}).");
    close LOG;
}

#####
# Usage: &compress($file);
sub compress {
    my ($file) = @_;
    my @compress = ("/usr/bin/bzip2","/bin/gzip");
    my $okay = 0;

    if (! -f $file) {
	# ironically this does not get logged :)
	&WARN("compress: file ($file) does not exist.");
	return 0;
    }

    if (-f "$file.gz" or -f "$file.bz2") {
	&WARN("compress: file.(gz|bz2) already exists.");
	return 0;
    }

    foreach (@compress) {
	next unless ( -x $_);

	&status("Compressing '$file' with $_.");
	system("$_ $file &");
	$okay++;
	last;
    }

    if (!$okay) {
	&ERROR("no compress program found.");
	return 0;
    }

    return 1;
}

sub DEBUG {
    return unless (&IsParam("DEBUG"));

    &status("${b_green}!DEBUG!$ob $_[0]");
}

sub ERROR {
    &status("${b_red}!ERROR!$ob $_[0]");
}

sub WARN {
    return unless (&IsParam("WARN"));

    &status("${b_yellow}!WARN!$ob $_[0]");
}

sub FIXME {
    &status("${b_cyan}!FIXME!$ob $_[0] (SHOULD NOT HAPPEN?)");
}

sub TODO {
    &status("${b_cyan}!TODO!$ob $_[0]");
}

sub VERB {
    if (!&IsParam("VERBOSITY")) {
	# NOTHING.
    } elsif ($param{'VERBOSITY'} eq "1" and $_[1] <= 1) {
	&status($_[0]);
    } elsif ($param{'VERBOSITY'} eq "2" and $_[1] <= 2) {
	&status($_[0]);
    }
}

sub status {
    my($input) = @_;
    my $status;

    # return if input is null'ish.
    return '' if ($input =~ /^\s*$/);
    $input =~ s/\n+$//;
    $input =~ s/\002|037//g;	# bold,video,underline => remove.

    # pump up the stats (or loglinenum).
    $statcount++;

    # fix style of output if process is child.
    if (defined $bot_pid and $$ != $bot_pid and !defined $statcountfix) {
	$statcount	= 1;
	$statcountfix	= 1;
    }

    ### LOG THROTTLING.
    ### TODO: move this _after_ printing?
    my $time = time();
    my $reset = 0;
    if ($logtime != $time) {
	$reset++;
    } elsif ($logtime == $time) {
	if ($logcount < 25) {		# too high?
	    $logcount++;
	} else {
	    sleep 1;
	    &status("LOG: Throttling.");	# recursive?
	    $reset++;
	}
    }
    if ($reset) {
	$logtime	= $time;
	$logcount	= 0;
    }

    # Log differently for forked/non-forked output.
    if ($statcountfix) {
	$status = "!$statcount! ".$input;
	if ($statcount > 1000) {
	    print LOG "ERROR: FORKED PROCESS RAN AWAY; KILLING.\n";
	    exit 0;
	}
    } else {
	$status = "[$statcount] ".$input;
    }

    if (&IsParam("backlog")) {
	push(@backlog, $status);	# append to end.
	shift(@backlog) if (scalar @backlog > $param{'backlog'});
    }

    if (&IsParam("VERBOSITY")) {
	if ($statcountfix) {
	    printf $_red."!%5d!".$ob." ", $statcount;
	} else {
	    printf $_green."[%5d]".$ob." ", $statcount;
	}

	# three uberstabs to Derek Moeller.
	my $printable = $input;

	if ($printable =~ s/^(<\/\S+>) //) {
	    # it's me saying something on a channel
	    my $name = $1;
	    print "$b_yellow$name $printable$ob\n";
	} elsif ($printable =~ s/^(<\S+>) //) {
	    # public message on channel.
	    my $name = $1;

	    if ($addressed) {
		print "$b_red$name $printable$ob\n";
	    } else {
		print "$b_cyan$name$ob $printable$ob\n";
	    }

	} elsif ($printable =~ s/^\* (\S+)\/(\S+) //) {
	    # public action.
	    print "$b_white*$ob $b_cyan$1$ob/$b_blue$2$ob $printable\n";
	} elsif ($printable =~ s/^(-\S+-) //) {
	    # notice
	    print "$_green$1 $printable$ob\n";
	} elsif ($printable =~ s/^(\* )?(\[\S+\]) //) {
	    # message/private action from someone
	    print "$b_white$1$ob" if (defined $1);
	    print "$b_red$2 $printable$ob\n";
	} elsif ($printable =~ s/^(>\S+<) //) {
	    # i'm messaging someone
	    print "$b_magenta$1 $printable$ob\n";
	} elsif ($printable =~ s/^(enter:|update:|forget:) //) {
	    # something that should be SEEN
	    print "$b_green$1 $printable$ob\n";
	} else {
	    print "$printable\n";
	}
    }

    # log the line into a file.
    return unless (&IsParam("logfile"));
    return unless ($loggingstatus);

    # remove control characters from logging.
    $input =~ s/\e\[[0-9;]+m//g;
    $input =~ s/[\cA-\c_]//g;
    $input = "FORK($$) ".$input if ($statcountfix);

    my $date;
    if (&IsParam("logType") and $param{'logType'} =~ /DAILY/i) {
	$date = sprintf("%02d:%02d.%02d", (localtime(time()))[2,1,0]);

	my ($day,$month,$year) = (localtime(time()))[3,4,5];
	my $newlogDate = sprintf("%04d%02d%02d",$year+1900,$month+1,$day);
	if (defined $logDate and $newlogDate != $logDate) {
	    &closeLog();
	    &compress($file{log});
	    &openLog();
	}
    } else {
	$date = time();
    }

    print LOG sprintf("%s %s\n", $date, $input);
}

1;
