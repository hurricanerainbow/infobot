#!/usr/bin/perl -w

# hrm...
#use strict;

my @test;
my @test1;
my %test;

$test{'hash0r'} = 2;
$test{'hegdfgsd'} = 'GSDFSDfsd';

push(@test1,"Aeh.");
push(@test1,"Beh.");
push(@test1,"Ceh.");
push(@test1,"Deh.");

push(@test,"heh.");
push(@test,\%test);
#push(@test,\%ENV);
push(@test,\@test1);

print "=============start=================\n";
#&DumpArray(0, '@test', \@test);
&DumpPackage(0, 'main::', \%main::);

# SCALAR ARRAY HASH CODE REF GLOB LVALUE
sub DumpArray {
 my ($pad, $symname, $arrayref) = @_;
 my $padding = " " x $pad;
 my $scalar = 0;
 my $size   = 0;

 print "$padding$symname\n";
 foreach (@{$arrayref}) {
  my $ref = ref $_;
  if ($ref eq 'ARRAY') {
   $size += &DumpArray($pad+1, "@" . $_, $_);
  } elsif ($ref eq 'HASH') {
   $size += &DumpHash($pad+1, "%" . $_, $_);
  } else {
   print "$padding $_ $ref\n";
   $scalar++;
   $size += length($_);
  }
 }
 print $padding."scalars $scalar, size $size\n";
 return $size;
}

sub DumpHash{
 my ($pad, $symname, $hashref) = @_;
 my $padding = " " x $pad;
 my $scalar = 0;
 my $size   = 0;

 my %sym = %{$hashref};
 my @list = sort keys %sym;
 print "$padding$symname\n";

 foreach (@list) {
  my $ref = ref %{$symname};
  $size += length($_);
  if ($ref eq 'ARRAY') {
   $size += &DumpArray($pad+1, "@" . $_, $_);
  } elsif ($ref eq 'HASH') {
   $size += &DumpHash($pad+1, "%" . $_, $_);
  } else {
   print "$padding $_=$sym{$_} $ref\n";
   $scalar++;
   $size += length($sym{$_});
  }
 }
 print $padding."scalars $scalar, size $size\n";
 return $size;
}

sub DumpPackage {
 my ($pad, $packname, $package) = @_;
 my $padding = " " x $pad;
 my $scalar = 0;
 my $size   = 0;

 print $padding . "\%$packname\n";
 my $symname;
 foreach $symname (sort keys %$package) {
  local *sym = $$package{$symname};
  print "$padding \$$symname='$sym'\n" if (defined $sym);
  $size += &DumpArray($pad+1, $symname, \@sym) if (defined @sym);
  $size += &DumpHash($pad+1, $symname, \%sym) if (defined %sym);
  $size += &DumpPackage($pad+1, \%sym, $symname) if (($symname =~ /::/) and ($symname ne 'main::'));
 }
 print $padding."scalars $scalar, size $size\n";
 return $size;
}
