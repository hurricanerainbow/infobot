#   Units.pl: convert units of measurement
#     Author: M-J. Dominus (mjd-perl-units-id-iut+buobvys+@plover.com)
#    License: GPL, Copyright (C) 1996,1999
#       NOTE: Integrated into blootbot by xk.

package Units;

# use strict;	# TODO

#$DEBUG_p = 1;
#$DEBUG_o = 1;
#$DEBUG_l = 1;
my %unittab;			# Definitions loaded here

# Metric prefixes.  These must be powers of ten or change the
# token_value subroutine
BEGIN {
  %PREF = (yocto => -24,
	   zepto => -21,
	   atto => -18,
	   femto => -15,
	   pico => -12,
	   nano => -9,
	   micro => -6,
#	      u => -6,
	   milli => -3,
	   centi => -2,
	   deci => -1,
	   deca => 1,
	   deka => 1,
	   hecto => 2,
	   hect => 2,
	   kilo => 3,
	   myria => 4,
	   mega => 6,
	   giga => 9,
	   tera => 12,
	   peta => 15,
	   exa => 18,
	   yotta => 21,
	   zetta => 24,
	  );
  $PREF = join '|', sort { $PREF{$a} <=> $PREF{$b} } (keys %PREF);
}


################################################################
#
# Main program here
#
################################################################

{ my $defs_read = 0;
  $defs_read += read_defs("$::bot_data_dir/unittab");

  unless ($defs_read) {
    &::ERROR("Could not read any of the initialization files UNITTAB");
    return;
  }
}

sub convertUnits {
  my ($from,$to) = @_;

  # POWER HACK.
  $from =~ s/\^(\-?\d+)/$1/;
  $to   =~ s/\^(\-?\d+)/$1/;
  my %powers = (
	2	=> 'squared?',
	3	=> 'cubed?',
  );
  foreach (keys %powers) {
    $from =~ s/(\D+) $powers{$_}$/$1\Q$_/;
    $to   =~ s/(\D+) $powers{$_}$/$1\Q$_/;
  }
  # END OF POWER HACK.

  ### FROM:
  trim($from);
  if ($from =~ s/^\s*\#\s*//) {
    if (definition_line($from)) {
      &::DEBUG("Defined.");
    } else {
      &::DEBUG("Error: $PARSE_ERROR.");
    }
    &::DEBUG("FAILURE 1.");
    return;
  }
  unless ($from =~ /\S/) {
    &::DEBUG("FAILURE 2");
    return;
  }

  my $hu = parse_unit($from);
  if (is_Zero($hu)) {
    &::DEBUG($PARSE_ERROR);
    &::msg($::who, $PARSE_ERROR);
    return;
  }

  ### TO:
  my $wu;
  trim($to);
  redo unless $to =~ /\S/;
  $wu = parse_unit($to);
  if (is_Zero($wu)) {
    &::DEBUG($PARSE_ERROR);
  }

  my $quot = unit_divide($hu, $wu);
  if (is_dimensionless($quot)) {
    my $q = $quot->{_};
    if ($q == 0) {
	&::performStrictReply("$to is an invalid unit?");
	return;
    }
    # yet another powers hack.
    $from =~ s/([[:alpha:]]+)(\d)/$1\^$2/g;
    $to   =~ s/([[:alpha:]]+)(\d)/$1\^$2/g;

    &::performStrictReply(sprintf("$from is approximately \002%.6g\002 $to", $q));
  } else {
    &::performStrictReply("$from cannot be correctly converted to $to.");

#    print
#      "conformability (Not the same dimension)\n",
#      "\t", $from, " is ", text_unit($hu), "\n",
#      "\t", $to, " is ", text_unit($wu), "\n",
#      ;
  }
}


################################################################

sub read_defs {
  my ($file) = @_;
  unless (open D, $file) {
    if ($show_file_loading) {
      print STDERR "Couldn't open file `$file': $!; skipping.\n";
    }
    return 0;
  }
  while (<D>) {
    s/\#.*$//;
    trim($_);
    next unless /\S/;

    print ">>> $_\n" if $DEBUG_d;
    my $r = definition_line($_);
    unless (defined $r) {
      warn "Error in line $. of $file: $PARSE_ERROR.  Skipping.\n";
    }
  }
  print STDERR "Loaded file `$file'.\n" if $show_file_loading;
  return 1;
}

sub definition_line {
  my ($line) = @_;
  my ($name, $data) = split /\s+/, $line, 2;
  my $value = parse_unit($data);
  if (is_Zero($value)) {
    return;
  }
  if (is_fundamental($value)) {
    return $unittab{$name} = {_ => 1, $name => 1};
  } else {
    return $unittab{$name} = $value;
  }
}

sub trim {
  $_[0] =~ s/\s+$//;
  $_[0] =~ s/^\s+//;
}

sub Zero () { +{ _ => 0 } }

sub is_Zero {
  $_[0]{_} == 0;
}

sub unit_lookup {
  my ($name) = @_;
  print STDERR "Looking up unit `$name'\n" if $DEBUG_l;
  return $unittab{$name} if exists $unittab{$name};
  if ($name =~ /s$/) {
    my $shortname = $name;
    $shortname =~ s/s$//;
    return $unittab{$shortname} if exists $unittab{$shortname};
  }
  my ($prefix, $rest) = ($name =~ /^($PREF-?)(.*)/o);
  unless ($prefix) {
    $PARSE_ERROR = "Unknown unit `$name'";
    return Zero;
  }
  my $base_unit = unit_lookup($rest); # Recursive
  con_multiply($base_unit, 10**$PREF{$prefix});
}

sub unit_multiply {
  my ($a, $b) = @_;
  print STDERR "Multiplying @{[%$a]} by @{[%$b]}: \n" if $DEBUG_o;
  my $r = {%$a};
  $r->{_} *= $b->{_};
  my $u;
  for $u (keys %$b) {
    next if $u eq '_';
    $r->{$u} += $b->{$u};
  }
  print STDERR "\tResult: @{[%$r]}\n" if $DEBUG_o;
  $r;
}

sub unit_divide {
  my ($a, $b) = @_;
  if ($b->{_} == 0) {
    &::DEBUG("Division by zero error");
    return;
  }
  my $r = {%$a};
  $r->{_} /= $b->{_};
  my $u;
  for $u (keys %$b) {
    next if $u eq '_';
    $r->{$u} -= $b->{$u};
  }
  $r;
}

sub unit_power {
  my ($p, $u) = @_;
  print STDERR "Raising unit @{[%$u]} to power $p.\n" if $DEBUG_o;
  my $r = {%$u};
  $r->{_} **= $p;
  my $d;
  for $d (keys %$r) {
    next if $d eq '_';
    $r->{$d} *= $p;
  }
  print STDERR "\tResult: @{[%$r]}\n" if $DEBUG_o;
  $r;
}

sub unit_dimensionless {
  print "Turning $_[0] into a dimensionless unit.\n" if $DEBUG_o;
  return +{_ => $_[0]};
}

sub con_multiply {
  my ($u, $c) = @_;
  print STDERR "Multiplying unit @{[%$u]} by constant $c.\n" if $DEBUG_o;
  my $r = {%$u};
  $r->{_} *= $c;
  print STDERR "\tResult: @{[%$r]}\n" if $DEBUG_o;
  $r;
}

sub is_dimensionless {
  my ($r) = @_;
  my $u;
  for $u (keys %$r) {
    next if $u eq '_';
    return if $r->{$u} != 0;
  }
  return 1;
}

# Generate bogus unit value that signals that a new fundamental unit
# is being defined
sub new_fundamental_unit {
  return +{__ => 'new', _ => 1};
}

# Recognize this  bogus value when it appears again.
sub is_fundamental {
  exists $_[0]{__};
}

sub text_unit {
  my ($u) = @_;
  my (@pos, @neg);
  my $k;
  my $c = $u->{_};
  for $k (sort keys %$u) {
    next if $k eq '_';
    push @pos, $k if $u->{$k} > 0;
    push @neg, $k if $u->{$k} < 0;
  }
  my $text = ($c == 1 ? '' : $c);
  my $d;
  for $d (@pos) {
    my $e = $u->{$d};
    $text .= " $d";
    $text .= "^$e" if $e > 1;
  }

  $text .= ' per' if @neg;
  for $d (@neg) {
    my $e = - $u->{$d};
    $text .= " $d";
    $text .= "^$e" if $e > 1;
  }

  $text;
}
################################################################
#
# I'm the parser
#

BEGIN {
  sub sh { ['shift', $_[0]]  };
  sub go { ['goto', $_[0]] };
  @actions =
    (
     # Initial state
     {PREFIX => sh(1),
      NUMBER => sh(2),
      NAME   => sh(3),
      FUNDAMENTAL => sh(4),
      FRACTION => sh(5),
      '(' => sh(6),
      'unit' => go(7),
      'topunit' => go(17),
      'constant' => go(8),
     },
     # State 1:   constant -> PREFIX .
     { _ => ['reduce', 1, 'constant']},
     # State 2:   constant -> NUMBER .
     { _ => ['reduce', 1, 'constant']},
     # State 3:   unit -> NAME .
     { _ => ['reduce', 1, 'unit', \&unit_lookup ]},
     # State 4:   unit -> FUNDAMENTAL .
     { _ => ['reduce', 1, 'unit', \&new_fundamental_unit ]},
     # State 5:   constant -> FRACTION .
     { _ => ['reduce', 1, 'constant']},
     # State 6:   unit -> '(' . unit ')'
     {PREFIX => sh(1),
      NUMBER => sh(2),
      NAME   => sh(3),
      FUNDAMENTAL => sh(4),
      FRACTION => sh(5),
      '(' => sh(6),
      'unit' => go(9),
      'constant' => go(8),
     },
     # State 7:   topunit -> unit .
     #            unit  ->  unit . TIMES unit
     #            unit  ->  unit . DIVIDE unit
     #            unit  ->  unit . NUMBER
     {NUMBER => sh(10),
      TIMES => sh(11),
      DIVIDE => sh(12),
      _ =>  ['reduce', 1, 'topunit'],
     },
     # State 8:   unit -> constant . unit
     #            unit -> constant .
     {PREFIX => sh(1),
      NUMBER => sh(2), # Shift-reduce conflict resolved in favor of shift
      NAME   => sh(3),
      FUNDAMENTAL => sh(4),
      FRACTION => sh(5),
      '(' => sh(6),
      _ =>   ['reduce', 1, 'unit', \&unit_dimensionless],
      'unit' => go(13),
      'constant' => go(8),
     },
     # State 9:   unit -> unit . TIMES unit
     #            unit -> unit . DIVIDE unit
     #            unit -> '(' unit . ')'
     #            unit -> unit . NUMBER
     {NUMBER => sh(10),
      TIMES => sh(11),
      DIVIDE => sh(12),
      ')' => sh(14),
     },
     # State 10:  unit -> unit NUMBER .
     { _ => ['reduce', 2, 'unit',
	     sub {
	       unless (int($_[1]) == $_[1]) {
		 ABORT("Nonintegral power $_[1]");
		 return Zero;
	       }
	       unit_power(@_);
	     }
	    ],
     },
     # State 11:  unit -> unit TIMES . unit
     {PREFIX => sh(1),
      NUMBER => sh(2),
      NAME   => sh(3),
      FUNDAMENTAL => sh(4),
      FRACTION => sh(5),
      '(' => sh(6),
      'unit' => go(15),
      'constant' => go(8),
     },
     # State 12:  unit -> unit DIVIDE . unit
     {PREFIX => sh(1),
      NUMBER => sh(2),
      NAME   => sh(3),
      FUNDAMENTAL => sh(4),
      FRACTION => sh(5),
      '(' => sh(6),
      'unit' => go(16),
      'constant' => go(8),
     },
     # State 13:  unit -> unit . TIMES unit
     #            unit -> unit . DIVIDE unit
     #            unit -> constant unit .
     #            unit -> unit . NUMBER
     {NUMBER => sh(10), # Shift-reduce conflict resolved in favor of shift
      TIMES => sh(11),  # Shift-reduce conflict resolved in favor of shift
      DIVIDE => sh(12), # Shift-reduce conflict resolved in favor of shift
      _ => ['reduce', 2, 'unit', \&con_multiply],
     },
     # State 14: unit => '(' unit ')' .
     { _ => ['reduce', 3, 'unit', sub {$_[1]}] },
     # State 15: unit  ->  unit . TIMES unit
     #           unit  ->  unit TIMES unit .
     #           unit  ->  unit . DIVIDE unit
     #           unit  ->  unit . NUMBER
     {NUMBER => sh(10), # Shift-reduce conflict resolved in favor of shift
      _ => ['reduce', 3, 'unit', sub {unit_multiply($_[0], $_[2])}],
     },
     # State 16: unit  ->  unit . TIMES unit
     #           unit  ->  unit DIVIDE unit .
     #           unit  ->  unit . DIVIDE unit
     #           unit  ->  unit . NUMBER
     {NUMBER => sh(10), # Shift-reduce conflict resolved in favor of shift
      _ => ['reduce', 3, 'unit', sub{unit_divide($_[2], $_[0])}],
     },
     # State 17: Finishing path
     {EOF => go(18),},
     # State 18: Final state
     {_ => ['accept']},
    );
}

sub ABORT {
  $PARSE_ERROR = shift;
}

sub parse_unit {
  my ($s) = @_;
  my $tokens = lex($s);
  my $STATE = 0;
  my (@state_st, @val_st);

  $PARSE_ERROR = undef;

  # Now let's run the parser
  for (;;) {
    return Zero if $PARSE_ERROR;
    my $la = @$tokens ? token_type($tokens->[0]) : 'EOF';
    print STDERR "Now in state $STATE.  Lookahead type is $la.\n" if $DEBUG_p;
    print STDERR "State stack is (@state_st).\n" if $DEBUG_p;
    my $actiontab = $actions[$STATE];
    my $action = $actiontab->{$la} || $actiontab->{_};
    unless ($action) {
      $PARSE_ERROR = 'Syntax error';
      return Zero;
    }

    my ($primary, @actargs) = @$action;
    print STDERR "  $primary (@actargs)\n" if $DEBUG_p;
    if ($primary eq 'accept') {
      return $val_st[0];	# Success!
    } elsif ($primary eq 'shift') {
      my $token = shift @$tokens;
      my $val = token_value($token);
      push @val_st, $val;
      push @state_st, $STATE;
      $STATE = $actargs[0];
    } elsif ($primary eq 'goto') {
      $STATE = $actargs[0];
    } elsif ($primary eq 'reduce') {
      my ($n_args, $result_type, $semantic) = @actargs;
      my @arglist;
#      push @state_st, 'FAKE';	# So that we only really remove n-1 states
      while ($n_args--) {
	push @arglist, pop @val_st;
	$STATE = pop @state_st;
      }
      my $result = $semantic ? &$semantic(@arglist) : $arglist[0];
      push @val_st, $result;
      push @state_st, $STATE;
#      $STATE = $state_st[-1];
      print STDERR "Post-reduction state is $STATE.\n" if $DEBUG_p;

      # Now look for `goto' actions
      my $goto = $actions[$STATE]{$result_type};
      unless ($goto && $goto->[0] eq 'goto') {
	&::ERROR("No post-reduction goto in state $STATE for $result_type.");
	return;
      }
      print STDERR "goto $goto->[1]\n" if $DEBUG_p;
      $STATE = $goto->[1];
    } else {
      &::ERROR("Bad primary $primary");
      return;
    }
  }
}


sub lex {
  my ($s) = @_;
  my @t = split /(
		   \*{3}        # Special `new unit' symbol
		|  [()*-]	# Symbol
		|  \s*(?:\/|\bper\b)\s*      # Division
		|  \d*\.\d+(?:[eE]-?\d+)? # Decimal number
		|  \d+\|\d+     # Fraction
		|  \d+          # Integer
#		|  (?:$PREF)-?  # Prefix (handle differently)
		|  [A-Za-z_][A-Za-z_.]* # identifier
		|  \s+		# White space
		)/ox, $s;
  @t = grep {$_ ne ''} @t;	# Discard empty and all-white tokens
  \@t;
}

sub token_type {
  my ($token) = @_;
  return $token->[0] if ref $token;
  return $token if $token =~ /[()]/;
  return TIMES if $token =~ /^\s+$/;
  return FUNDAMENTAL if $token eq '***';
  return DIVIDE if $token =~ /^\s*(\/|\bper\b)\s*$/;
  return TIMES if $token eq '*' || $token eq '-';
  return FRACTION if $token =~ /^\d+\|\d+$/;
  return NUMBER if $token =~ /^[.\d]/;
#  return PREFIX if $token =~ /^$PREF/o;
  return NAME;
}

sub token_value {
  my ($token) = @_;
  return $token if $token =~ /^([()*\/-]|\s*\bper\b\s*)$/;
  if ($token =~ /(\d+)\|(\d+)/) {
    if ($2 == 0) {
      ABORT("Zero denominator in fraction `$token'");
      return 0;
    }
    return $1/$2;
#  } elsif ($token =~ /$PREF/o) {
#    $token =~ s/-$//;
#    return 10**($PREF{$token});
  }
  return $token;		# Perl takes care of the others.
}

1;
