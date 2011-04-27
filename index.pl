#!/usr/bin/perl

use IR;
use Time::HiRes qw(gettimeofday);

my $collection_path=shift;
my $destination=`pwd`;
chomp($destination);
my $corpus = $destination."/produced/corpus-data/corpus-tf";
$destination = $destination."/data";

$t1 = gettimeofday();
if (not (-d "produced_dynamic")) {
    `mkdir produced_dynamic`;
}
process_collection($collection_path,$destination);
create_index($destination);
$t2 = gettimeofday();

$size = `du -s -b $corpus`;
($x, $y) = split(/\s/, $size);

print "Total time taken for indexing: ";
print $t2-$t1." seconds.\n";

print "Disk usage: $x bytes\n";
