#!/usr/bin/perl

use IO::Socket::INET;
use dynamic_index;
use utils;
use merge;
use Time::HiRes qw(gettimeofday);

=pod

=head1 NAME

rti_engine

=head1 SYNOPSIS

rti_engine

=head1 DESCRIPTION

This program is the main real time indexing engine
always waiting for signal from detectchange.pl.
Upon receiving the list of documents changed from 
the Document Modification Detector, it initiates 
the creation of a dynamic index. It is also responsible 
for initiating the process of merging dynamic indexes 
to the main index.

=cut

# flush after every write
$| = 1;

if (scalar @ARGV ne 1) {
    print "Usage: ./rti_engine.pl <threshold value>\n";
    exit(0)
}

my $THRESHOLD = shift;
my ($socket,$received_data);
my ($peeraddress,$peerport);

#  we call IO::Socket::INET->new() to create the UDP Socket and bound
# to specific port number mentioned in LocalPort and there is no need to provide
# LocalAddr explicitly as in TCPServer.
$socket = new IO::Socket::INET (
LocalPort => '5000',
Proto => 'udp',
) or die "ERROR in Socket Creation : $!\n";

my @files_in_dyn;
while(1)
{
    # read operation on the socket
    $socket->recv($received_data,4096);

    #get the peerhost and peerport at which the recent data received.
    $peer_address = $socket->peerhost();
    $peer_port = $socket->peerport();
    chomp($received_data);
#print "\n($peer_address , $peer_port) said : $received_data";
    my @files = split(/ /,$received_data);
    foreach $file (@files) {
        if (not (grep {$_ eq $file} @files_in_dyn)) {
            push (@files_in_dyn, $file);
        }
    }
    dynamic_index(@files);

    if ((scalar @files_in_dyn) > $THRESHOLD) {
        print "Time to merge!\n"; #$dyn_index_size, $main_index_size\n";
        $t1 = gettimeofday();
        merge_dyns_into_main();
        $t2 = gettimeofday();
        $t3 = $t2-$t1;
        print "Time taken to merge: $t3 seconds; #dyns = ". scalar @files_in_dyn;
        print "\n";
    }
}

$socket->close();

