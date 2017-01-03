#!/usr/bin/perl

use strict;
use warnings;

my $resrc = `cat $ARGV[0]`;
chomp $resrc;
open my $minfile, $ARGV[1] or die $ARGV[1];
while (my $line = <$minfile>) {
  chomp($line);
  my @captures = $line =~ /$resrc/;
  if (@captures) {
    print "«$&»\n";
    my $i = 1;
    for my $cap (@captures) {
      if (!defined($cap)) {
	print "$i: «null»\n";
      } else {
	print "$i: «$cap»\n";
      }
      $i++;
    }
  } else {
    print "\n";
  }
}
