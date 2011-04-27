#!/usr/bin/perl
use XML::Simple;
use Clair::Utils::CorpusDownload;
use Clair::Utils::Tf;
use Clair::Utils::TFIDFUtils;
use List::Util qw(first);
use Clair::Utils::Stem;
use Clair::Utils::TFIDFUtils;
use Cwd;
use Cwd 'abs_path';

=pod

=head1 NAME

utils

=head1 SYNOPSIS

utils

=head1 DESCRIPTION

This module supplies utility methods to other
modules which helps in real time indexing.

=head1 METHODS

B<get>

This method takes in three arguments.
a) root dir of index.
b) database name - EXPAND_DBM, COMPRESS_DBM, TO_URLS_DBM, TO_DOCID_DBM
c) key

It then gets the hash value associated with the key from the index 
and the database supplied.

Ex: $comp_id = get("produced", "TO_DOCID_DBM", $url);

B<convert_docid>

This method takes in a compressed doc id and a dynamic index
number and returns the corresponding doc id in the main index.

Ex: $c = convert_docid($id, $index);

B<convert_file>

This method takes a tf file in the dynamic index and returns
an equivalent tf file corresponding to the main index as a 
string

Ex: my $str = convert_file($tf_file, $dyn_index);

=cut

sub get {
    my $root = shift;
    my $database = shift;
    my $key = shift;

    my $tf = Clair::Utils::Tf->new(rootdir => $root, corpusname => "corpus", stemmed => 0);
    my $corpus = Clair::Utils::CorpusDownload->new(corpusname => "corpus", rootdir => $root);
    my $rootdir    = $tf->{rootdir};
    my $corpusname = $tf->{corpusname};
    my $corp = $corpus->{corpus};

    my $workdir = "$rootdir/corpus-data";
    my $tfdir = ( $stemmed ? "$workdir/$corpusname-tf-s" : "$workdir/$corpusname-tf" );
    my $EXPAND_DBM_NAME = "$workdir/$corpusname/$corpusname-expand-docid";
    my $COMPRESS_DBM_NAME = "$workdir/$corpusname/$corpusname-compress-docid";
    my $TO_URL_DBM_NAME = "$workdir/$corpusname/$corpusname-docid-to-url";
    my $TO_DOCID_DBM_NAME = "$workdir/$corpusname/$corpusname-url-to-docid";

    my %expand = ();
    my %compress = ();
    my %to_urls = ();
    my %to_docids = ();

    if ($database eq "EXPAND_DBM") {
        dbmopen %expand, $EXPAND_DBM_NAME, 0666 or
             die "Can't open '$EXPAND_DBM_NAME'";
        my $val = $expand{$key}; 
        dbmclose %expand;
        return $val;
    } elsif ($database eq "COMPRESS_DBM") {
        dbmopen %compress, $COMPRESS_DBM_NAME, 0666 or
            die "Can't open '$EXPAND_DBM_NAME'";
        my $val = $compress{$key}; 
        dbmclose %compress;
        return $val;
    } elsif ($database eq "TO_URL_DBM") {
        dbmopen %to_urls, $TO_URL_DBM_NAME, 0666 or
             die "Can't open '$TO_URL_DBM_NAME'";
        my $val = $to_urls{$key}; 
        dbmclose %to_urls;
        return $val;
    } elsif ($database eq "TO_DOCID_DBM") {
        dbmopen %to_docids, $TO_DOCID_DBM_NAME, 0666 or
            die "Can't open '$TO_DOCID_DBM_NAME'";
        my $val = $to_docids{$key}; 
        dbmclose %to_docids;
        return $val;
    }
}

sub convert_docid {
    my $id = shift;
    my $dyn_index = shift;

    $ex_id = get($dyn_index, "EXPAND_DBM", $id);
    $url = get($dyn_index, "TO_URL_DBM", $ex_id);
    $url =~ s/$dyn_index/produced/;

    $comp_id = get("produced", "TO_DOCID_DBM", $url);
    $major_id = get("produced", "COMPRESS_DBM", $comp_id);

    return $major_id;
}

sub convert_file {
    my $file = shift;
    my $index = shift;

    my $str = "";

    open FILE, $file;
    @lines = <FILE>;

    foreach $line (@lines) {
        ($a, @b) = split(/ /, $line);
        $c = convert_docid($a, $index);
#print "$c @b";
        $str = "$str"."$c @b";
    }
    return $str;
}

sub get_index_size {
    $index = shift;
    if ($index eq "produced") {
        $index = "$index/corpus-data/corpus-tf/";
        ($a, $b) = split(/\t/,`du -b -s $index`);
        return $a;
    } elsif ($index eq "produced_dynamic") {
        my @dirs = `ls $index`;
        my $s = 0;

        foreach $x (@dirs) {
            chomp($x);
            $c = "$index/$x/corpus-data/corpus-tf/";
            $a = 0;
            if (-d $c) {
                ($a, $b) = split(/\t/,`du -b -s $c`);
            }
            $s = $s + $a;
        }
        return $s;
    }
}

1;



