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

remove_file

=head1 SYNOPSIS

remove_file

=head1 DESCRIPTION

This module supplies the methods to remove a document
from an index.

=head1 METHODS

B<remove_doc_from_index>

This method takes a doc id and the root directory of
the index. It then removes the document from the index.

Ex: remove_doc_from_index($doc_id, "produced");

B<get_url>

This is a helper method which takes in a doc id and
a index root and returns the URL of the document in that
index.

Ex: get_url($doc_id, "produced");

B<remove_doc>

This method takes in a doc id in compressed form and
an index root and removes the doc from the index.

Ex: remove_doc($comp_id, "produced");

B<remove_doc_from_tf_file>

This method takes in a doc id in compressed form and
a tf (term frequency) file and removes the doc id
from that file. 

Ex: remove_doc_from_tf_file($id, $tf_file_path);


=cut

#my $id = shift;
#remove_doc_from_index($id);

sub remove_doc_from_index {
    my $doc_id = shift;
    my $index_root = shift;

    my $tf = Clair::Utils::Tf->new(rootdir => $index_root, corpusname => "corpus", stemmed => 0);
    my $corpus = Clair::Utils::CorpusDownload->new(corpusname => "corpus", rootdir => $index_root);
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

    dbmopen %to_urls, $TO_URL_DBM_NAME, 0666 or
             die "Can't open '$TO_URL_DBM_NAME'";

    dbmopen %expand, $EXPAND_DBM_NAME, 0666 or
             die "Can't open '$EXPAND_DBM_NAME'";

    dbmopen %compress, $COMPRESS_DBM_NAME, 0666 or
            die "Can't open '$EXPAND_DBM_NAME'";
         
    dbmopen %to_docids, $TO_DOCID_DBM_NAME, 0666 or
            die "Can't open '$TO_DOCID_DBM_NAME'";

    my $docid = $to_docids{get_url($doc_id, $index_root)};
    my $comp_id = $compress{$docid};

    remove_doc($index_root, $comp_id);
    if (is_index_dynamic($index_root)) {
        delete $compress{$docid};
        delete $expand{$comp_id};
        delete $to_urls{$docid};
        $url = get_url($doc_id, $index_root);
        delete $to_docids{$url};

        dbmclose %expand;
        dbmclose %compress;
        dbmclose %to_urls;
        dbmclose %to_docids;
    }
}

sub get_url {
    my $doc = shift;
    $index_root = shift;
    $pwd = `pwd`;
    chomp($pwd);
    return "http://$index_root/download/corpus/$pwd/data/$doc.txt";
}

sub remove_doc{
    my $workdir = shift;
    my $doc = shift;

    my ($startdir) = &cwd; # keep track of where we began

    chdir($workdir) or die "Unable to enter dir $workdir:$!\n";
    opendir(DIR, ".") or die "Unable to open $workdir:$!\n";
    my @names = readdir(DIR) or die "Unable to read $workdir:$!\n";
    closedir(DIR);

    foreach my $name (@names){
        next if ($name eq "."); 
        next if ($name eq "..");

        if (-d $name){                  # is this a directory?
            &remove_doc($name, $doc);
            next;
        }
        if ($name =~ /.*tf$/) {
            my $c = remove_doc_from_tf_file($doc, $name);
            if ($c eq 0) {
                unlink($name);
            }
        }
    }
    chdir($startdir) or 
           die "Unable to change to dir $startdir:$!\n";

    $p = abs_path($workdir);
    if($p =~ m/corpus-tf/) { 
        opendir(DIR, $workdir);
        my @names = readdir(DIR);
        closedir(DIR);
        if (scalar(@names) eq 2) {
            rmdir($workdir);
        }
    }
}

sub remove_doc_from_tf_file {
    $doc = shift;
    $tf_file = shift;

    my $c = 0;
    open FILE, $tf_file;
    @lines = <FILE>;
    close FILE;

    open FILE, ">$tf_file";
    my @res;

    foreach $line (@lines) {
        @sl = split(/ /,$line);
        push(@res, $line) if ($sl[0] ne $doc);
    }

    foreach $x (@res) {
        $c = $c + 1;
        print FILE $x;
    }
    close FILE;
    return $c;
}

1;
