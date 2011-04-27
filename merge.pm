#!/usr/bin/perl

use Cwd;
use Cwd 'abs_path';
use utils;

=pod

=head1 NAME

merge

=head1 SYNOPSIS

merge

=head1 DESCRIPTION

This module supplies the methods to merge two indexes
created by Clairlib library.

=head1 METHODS

B<merge_dyns_into_main>

This method is to be called when dynamic indexes need to be
merged to the main index. It assumes "produced" directory to
be the location of main index and "produced_dynamic" to be
the location of dynamic indexes. It also does the preparotory
work of removing the documents present in dynamic indexes 
from the main index.

Ex: merge_dyns_into_main();

B<merge>

This method does the actual merger operation. It takes two
arguments. The location of main index and the location of 
the individual dynamic index.

Ex: merge($main, "produced_dynamic/$index");

=cut

#$main = shift;
#$dyn = shift;

sub merge {
    $main_index = shift;
    $dyn_index = shift;
    $corpus = "corpus-data/corpus-tf";

    $main_corpus = "$main_index/corpus-data/corpus-tf"; 
    $dyn_corpus = "$dyn_index/corpus-data/corpus-tf"; 
    if (not -d $dyn_corpus) {
        return;
    }

    my $startdir = &cwd;

    chdir ($dyn_corpus);
    @dyn_list = `find .`;
    chdir ($startdir);

    chdir ($main_corpus);
    @main_list = `find .`;
    chdir ($startdir);

    shift(@main_list);
    shift(@dyn_list);

    %main_hash = ();
    foreach $p (@main_list) {
        chomp($p);
        $main_hash{$p} = 1;
    }
    
#chdir ($main_index);
    foreach $p (@dyn_list) {
        chomp($p);
        $p = substr $p, 1;
        if (exists $main_hash{".$p"}) {
            $m_file = "$main_corpus/$p";
            $d_file = "$dyn_index/$corpus/$p";
            if (-f $d_file) {
#print "Appending $d_file to $m_file\n";
                my $str = convert_file($d_file, $dyn_index);
                open MFILE, ">>$m_file";
                print MFILE $str;
                close MFILE;
            }
        } else {
            @path = split(/\//, $p);
            shift(@path);
            $incr_path = "";
            foreach $x (@path) {
                if ($incr_path eq "") {
                    $incr_path = $x;
                } else {
                    $incr_path = "$incr_path/$x";
                }
                if (-d "$dyn_corpus/$incr_path") {
                    if (not -d "$main_corpus/$incr_path") {
                        `mkdir "$main_corpus/$incr_path"`;
                    }
                } else {
                     open MFILE, ">$main_corpus/$incr_path";
                     my $str = convert_file("$dyn_corpus/$incr_path", $dyn_index);
                     print MFILE $str;
                     $pwdir = `pwd`;
#print "copying $dyn_corpus/$incr_path to $main_corpus/$incr_path\n";
                }
            }
        }
    }
}

sub merge_dyns_into_main {
    my $main = "produced";
    my @dyns = `ls produced_dynamic`;
    my $corpus = "corpus-data/corpus-tf";

    foreach $index (@dyns) {
        chomp($index);
        if (-d "produced_dynamic/$index/$corpus") {
            $pwd = `pwd`;
            chomp($pwd);
            $path = "produced_dynamic/$index/download/corpus/$pwd/data";
            my @files = `ls $path`;
            foreach $file (@files) {
                chomp($file);
                ($doc, $b) = split(/\./, $file);
                print "Removing $doc from main index\n";
                remove_doc_from_index($doc, $main);
            }
            print "Syncing produced_dynamic/$index to main\n";
            merge($main, "produced_dynamic/$index");
        }
        `rm -rf produced_dynamic/$index`;
    }
}

1;
