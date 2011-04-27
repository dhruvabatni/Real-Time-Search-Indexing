#!/usr/bin/perl

=pod

=head1 NAME

detectchange

=head1 SYNOPSIS

detectchange

=head1 DESCRIPTION

This program watches over a directory
and reports any changes to the documents
to the real time indexing engine listening
on UDP port 5000

=cut

use strict;
use File::Modified;

if (scalar (@ARGV) ne 3) {
    print "Usage: ./detectchange.pl <path> <ip_address> <notify duration>\n";
    exit(0);
}

my $PORT = 5000;
my $dir = shift;
my $ip = shift;
my $dur = shift;
my @files = `ls $dir`;
my $x;
my @a;

foreach $x (@files) {
    chomp($x);
    push(@a, "$dir/$x");
}
#my $d = File::Modified->new(files=>['a.txt','b.txt']);
  my $d = File::Modified->new(files=>\@a);

  while (1) {
    my (@changes) = $d->changed;

    if (@changes) {
      #print "$_ was changed\n" for @changes;
#`echo $_ | nc -u 127.0.0.1 $PORT` for @changes;
#`echo @changes | nc -u 127.0.0.1 $PORT`;
      `echo @changes | nc -u $ip $PORT`;
      $d->update();
    };
    sleep $dur;
  };
