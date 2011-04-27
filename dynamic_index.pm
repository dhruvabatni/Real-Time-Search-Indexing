#!/usr/bin/perl

use XML::Simple;
use Clair::Utils::CorpusDownload;
use Clair::Utils::Tf;
use Clair::Utils::TFIDFUtils;
use List::Util qw(first);
use Clair::Utils::Stem;
use Clair::Document;
use remove_file;
use utils;
use collection;

=pod

=head1 NAME

dynamic_index

=head1 SYNOPSIS

dynamic_index

=head1 DESCRIPTION

This module supplies the methods to create
a dynamic index.

=head1 METHODS

B<process_dynamic_collection>

This method takes a list of files to be dynamically indexed and does the
initial processing needed like parsing and extracting the document text.

Ex: my @file_data = process_dynamic_collection($destination, \@collection);

B<create_dynamic_index>

This method takes 2 arguments. A number and a list of files to be indexed.
The first argument number is the new dynamic index number. 

Ex: create_dynamic_index($num, @file_data);

B<dynamic_index>

This method takes in a list of documents to be indexed and creates a dynamic
index with the help of "create_dynamic_index" and "process_dynamic_collection"

Ex: dynamic_index(@files);

=cut

sub process_dynamic_collection{
   my $destination = shift;
   my $filesref = shift;

   my @files = @$filesref;
   my @file_data_path;

   print "parsing xml and storing metadata...\n";
#@files = `ls $source`;
   %title_meta=();
   dbmopen(%title_meta, "titles", 0666);
   %bibl_meta=();
   dbmopen(%bibl_meta, "bibl", 0666);
   %author_meta=();
   dbmopen(%author_meta, "authors", 0666);
   %length=();
   dbmopen(%length, "doclength", 0666);
   if(!(-d $destination)) {
       `mkdir $destination`;
   }
   foreach my $doc(@files){
       my $hash = parse_file("$doc");
       my $text =  $hash->{"TITLE"} . "\n" . $hash->{"TEXT"}. "\n" . $hash->{"AUTHOR"};
       my $docno = $hash->{"DOCNO"};
       $docno =~ s/[^0-9]*([0-9]+)[^0-9]*/$1/g;
       $str = "$destination/$docno.txt";
       push(@file_data_path, $str);
       open (FILE, ">$destination/$docno.txt") or die "Can't create file";
       print FILE $text;
       close (FILE);
       $title_meta{$docno} = $hash->{"TITLE"};
       $author_meta{$docno} = $hash->{"AUTHOR"};
       $text =~ s/\.//g; $text =~ s/,//g;
       my @doclength = split /\s+/, $text;
       $length{$docno} = scalar @doclength;
   }
   return @file_data_path;
}

sub create_dynamic_index{
   my $num = shift;
   my @files = @_;

   my $corpus = Clair::Utils::CorpusDownload->new(corpusname => "corpus", rootdir => "produced_dynamic/$num");
   $corpus->buildCorpusFromFiles(filesref => \@files, cleanup => 0,
                          safe => 1, skipCopy => 0);
   $corpus->buildIdf(stemmed => 0);
   $corpus->build_docno_dbm();
   $corpus->buildTf(stemmed => 0);
   $corpus->build_term_counts(stemmed => 0);
}

sub dynamic_index {
    my @collection = @_;

    my @dirs = `ls produced_dynamic`;
    my $num = scalar @dirs;

    my $destination=`pwd`;
    chomp($destination);
    $destination = $destination."/data";
    my @file_data = process_dynamic_collection($destination, \@collection);
    $num++;
    create_dynamic_index($num, @file_data);
    print "Dynamic index created, #$num\n";

    my $pwd = `pwd`;
    chomp($pwd);

    foreach $index (@dirs) {
        chomp($index);
        $latest_index_root = "produced_dynamic/$num";
        $path = "$pwd/$latest_index_root/download/corpus/$pwd/data";
        my @files = `ls $path`;
        foreach $file (@files) {
            chomp($file);
            ($doc, $b) = split(/\./, $file);
            remove_doc_from_index($doc, "produced_dynamic/$index");
        }
    }
}

sub is_index_dynamic {
    $root = shift;
    return ($root =~ m/dynamic/);
}

1;



