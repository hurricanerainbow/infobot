#
# Uptime.pl: Uptime daemon for infobot.
#    Author: dms
#   Version: v0.3 (19991008)
#   Created: 19990925.
#

use strict;

my $uptimerecords	= 3;

sub uptimeNow {
  return time() - $^T;
}

sub uptimeStr {
  my $uptimenow = &uptimeNow();

  if (defined $_[0]) {
    return "$uptimenow.$$ running $infobot_version, ended ". localtime(time());
  } else {
    return "$uptimenow running $infobot_version";
  }
}

sub uptimeGetInfo {
  my (%uptime,%done,%pid);
  my ($uptime,$pid);
  my @results;
  my $file = $file{utm};

  if (!open(IN, $file)) {
    &status("Writing uptime file for first time usage (nothing special).");
    open(OUT,">$file");
    close OUT;
  } else {
    while (<IN>) {
      chop;

      if (/^(\d+)\.(\d+) (.*)/) {
	  $uptime{$1}{$2} = $3;
      }
    }
    close IN;
  }

  &uptimeStr(1)   =~ /^(\d+)\.(\d+) (.*)/;
  $uptime{$1}{$2} = $3;

  # fixed up bad implementation :)
  # should be no problems, even if uptime or pid is duplicated.
  foreach $uptime (sort {$b <=> $a} keys %uptime) {
    foreach $pid (keys %{$uptime{$uptime}}) {
	next if (exists $done{$pid});

	push(@results,"$uptime.$pid $uptime{$uptime}{$pid}");
	$done{$pid} = 1;
	last if (scalar @results == $uptimerecords);
    }
    last if (scalar @results == $uptimerecords);
  }

  return @results;
}

sub uptimeWriteFile {
  my @results = &uptimeGetInfo();
  my $file = $file{utm};

  if (!open(OUT,">$file")) {
    &status("error: cannot write to $file.");
    return;
  }

  foreach (@results) {
    print OUT "$_\n";
  }

  close OUT;

  $conn->schedule(&getRandomInt("1800-3600"), \&uptimeWriteFile, "");
  return;
}

1;
