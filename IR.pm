=head1 NAME

IR

=head1 SYNOPSIS

    use IR

=head1 DESCRIPTION

This module includes APIs to simple information retreival system.

=head2 Methods

=over 12

=item C<parse_file>
:: Returns a hash of all XML elements.

=item C<process_collection>
:: Given a path to the collection fo files in XML format, it processes all the files to help with the next step - indexing.


=item C<create_index>
:: Given the path to the data, it creates an IDF index.


=item C<getAllDocKeys>
:: Returns all the document keys in the corpus.


=item C<negationResults>
:: Returns all the docs which contain a given phrase. This result is then used to prune the list obtained from getAllDocKeys.


=item C<execute_query>
:: Executes a query with the help of other APIs mentioned. Returns a list of documents relating to the query and their score in a hash table. Also returns a hash of location of the documents.


=item C<get_summary>
:: Given a docid and position where a phrase occurs, it returns a short summary of the line containing the phrase.


=item C<document_freq>
:: Given a phrase it returns the number of documents with that phrase.


=item C<index_freq>
:: Given a phrase it returns number of times this phrase occurs in the index.


=item C<document_text>
:: Given a document id, returns the text from the document which was indexed.


=item C<get_document_title>
:: Returns the title of document given a docid


=item C<produce_similar>
:: Helper function to get_similar_words


=item C<get_similar_words>
:: Takes in as argument a word and returns a list of all words that appear similar in context in decreasing order. It checks the previous word and the next word to determine the context. There is a delay added because of the complexity of this operation. For each pre and post word, corpus is queried to determine how many times these pre and post words occur. A count is taken of the words in between pre and post word and the count is used to rank the similarity.

=back

=head1 AUTHOR
Dhruva L Batni, dlb2155@columbia.edu

=cut


use XML::Simple;
use Clair::Utils::CorpusDownload;
use Clair::Utils::Tf;
use Clair::Utils::TFIDFUtils;
use List::Util qw(first);
use Clair::Utils::Stem;
use Clair::Document;
use collection;

sub create_index{
   my $data_source = shift;
   my $corpus = Clair::Utils::CorpusDownload->new(corpusname => "corpus", rootdir => "produced");
   $corpus->build_corpus_from_directory(dir=>"$data_source", cleanup => 0, relative => 1, skipCopy => 0);
   $corpus->buildIdf(stemmed => 0);
   $corpus->build_docno_dbm();
   $corpus->buildTf(stemmed => 0);
   $corpus->build_term_counts(stemmed => 0);
}

sub getAllDocKeys{
    $tf = shift;
   my $rootdir = $tf->{rootdir};
   my $corpusname = $tf->{corpusname};
   my $stemmed = $tf->{stemmed};
   my @urlsArray;

   # Prepare stemmer (but only use if tf is stemmed)
   my $stemmer = Lingua::Stem->new(-locale => 'EN-US');
   $stemmer->stem_caching({-level => 2});

    my $workdir = "$rootdir/corpus-data";
   my $tfdir = ($stemmed ? "$workdir/$corpusname-tf-s" : "$workdir/$corpusname-tf" );
   my $TO_DOCID_DBM_NAME = "$workdir/$corpusname/$corpusname-url-to-docid";

   my %to_docids = ();
   dbmopen %to_docids, $TO_DOCID_DBM_NAME, 0666 or die "Can't open '$TO_DOCID_DBM_NAME'";
   my %allUrls = %to_docids;
   dbmclose %to_docids; 
   
   foreach my $key(keys %allUrls) {
        $key =~ s/.*\/([0-9]+)\.txt/$1/g;
        push(@urlsArray, $key);
   }
   my %urls = ();
   foreach $url(@urlsArray) {
        $urls{$url} = 1;
   }

   return %urls;
}

sub negationResults{
    my $negation = @_[0];
    my $tf = @_[1];
    my @urlList;

    foreach $term(@$negation) {
        my @words = split(/ /, $term);
        $numWords = @words;
        my $urls = $tf->getDocsWithPhrase(@words);
        foreach my $key (keys %$urls){
            $key =~ s/.*\/([0-9]+)\.txt/$1/g;
            push(@urlList, $key);
        }
    }
    return @urlList;
}

sub execute_query_real_time {
    my @searchTerms = @_;

    my ($ref, $locref) = execute_query("produced", @searchTerms);

    my %results = %$ref;
    my %locations = %$locref;

    @dyns = `ls produced_dynamic`;
    my %dyn_docs = ();

    foreach $index (@dyns) {
        chomp($index);
        my $tf = Clair::Utils::Tf->new(rootdir => "produced_dynamic/$index", corpusname => "corpus", stemmed => 0);
        my %out = getAllDocKeys($tf);
        foreach $key (keys %out) {
            if (exists $dyn_docs{$key}) {
                print "Something wrong. duplicate doc in dyn index, $key\n";
            }
            $dyn_docs{$key} = 1;
        }
    }
    foreach $key (keys %results) {
        if (exists $dyn_docs{$key}) {
            delete $results{$key};
        }
    }
    foreach $key (keys %locations) {
        if (exists $dyn_docs{$key}) {
            delete $locations{$key};
        }
    }

    foreach $index (@dyns) {
        chomp($index);
        print "Executing query on produced_dynamic/$index\n";
        my ($ref_d, $locref_d) = execute_query("produced_dynamic/$index", @searchTerms);
        my %results_d = %$ref_d;
        my %locations_d = %$locref_d;
        
        foreach $key (keys %results_d) {
            $results{$key} = $results_d{$key};
        }
        foreach $key (keys %locations_d) {
            $locations{$key} = $locations_d{$key};
        }
    }
    return \%results, \%locations;
}

sub execute_query{
#my @searchTerms = @_;
   my ($index_root, @searchTerms) = @_;

   my $tf = Clair::Utils::Tf->new(rootdir => $index_root, corpusname => "corpus", stemmed => 0);
   my %results = ();
   my %out = ();
   my %location = ();
   my @negation;
   my $negationOnly = 1;
   foreach $term(@searchTerms){
       if ($term=~ s/!//g){
           push(@negation, $term);
       }else{
           $negationOnly = 0;
           my @words = split(/ /, $term);
           $numWords = @words;
           my $urls = $tf->getDocsWithPhrase(@words);

           foreach my $key (keys %$urls){
               $ref = $urls->{$key};
               $toAdd = keys(%$ref) * $numWords;
               $key =~ s/.*\/([0-9]+)\.txt/$1/g;
               if (!exists $location{$key}){
                   my ($position, $storedVal) = each %$ref;  #just need the first position
                   $location{$key} = $position;
               }
               if (exists $out{$key}){
                   $out{$key}+= $toAdd;
               }else{
                   $out{$key}=$toAdd;
               }
           }
       }
   }
   if ($negationOnly == 1){
       %out = getAllDocKeys($tf);
       foreach my $key(keys %out){
           $location{$key} = 0;
       }
   }
   if ((scalar @negation) > 0){
       my @negatedDocs = negationResults(\@negation, $tf);
       foreach $removeDoc(@negatedDocs){
           if (exists $out{$removeDoc}){
               delete $out{$removeDoc};
           }
       }
   }
   return \%out, \%location;
}

sub get_summary{
   my ($docId, $position) = @_;
   if (not -e "data/$docId.txt") {
       return "";
   }
   my $text = `cat data/$docId.txt`;
   $text =~ s/\s\./\./g;
   my $return = "";
   my $start = 0;
   @words = split /\s+/,$text;
   if ($position > 11){
       $start = $position - 11;
   }
   for($count = $start; $count <= ($start+20); $count++){
       if (exists $words[$count]){$return .= "$words[$count] ";}
       if ($count == $start +10){$return .= "\n\t\t";}
   }
   return $return;
}

sub document_freq{
    $term = shift;
    my $tf = Clair::Utils::Tf->new(rootdir => "produced", corpusname => "corpus", stemmed => 0);
    my @ph = ();

    push(@ph, split(/\s+/, $term));

    return $tf->getNumDocsWithPhrase(@ph);
}

sub index_freq{
    $term = shift;
    my $tf = Clair::Utils::Tf->new(rootdir => "produced", corpusname => "corpus", stemmed => 0);
    my @ph = ();

    push(@ph, split(/\s+/, $term));

    return $tf->getPhraseFreq(@ph);
}

sub document_text{
    $doc = shift;
    if (not -e "data/$doc.txt") {
        return "";
    }
    return `cat data/$doc.txt`;
}

sub get_document_title{
    $doc = shift;
    if (not -e "data/$doc.txt") {
        return "";
    }
    open DOC, "data/$doc.txt";
    $s1 = <DOC>;
    $s2 = <DOC>;
    $s3 = <DOC>;
    $s4 = <DOC>;
    $s = $s1.$s2.$s3.$s4;
    chomp($s);
    return $s;
}

sub document_term_freq{
    $doc = @_[0];
    $term = @_[1];

    my @ph = ();
    my $tf = Clair::Utils::Tf->new(rootdir => "produced", corpusname => "corpus", stemmed => 0);

    push(@ph, split(/\s+/, $term));

#($count, $pos) = $tf->getPhraseFreqInDocument(\@ph, url => Clair::Utils::TFIDFUtils::docid_to_url($doc, "corpus"));
    ($count, $pos) = $tf->getPhraseFreqInDocument(\@ph, url => "data/$doc.txt");
    return $count;
}

sub produce_similar{
    $context = shift;
    $w = shift;
    %similar = ();
    %duplicates = ();

    foreach $x (keys %$context) {
        ($pre, $post) = split(/ /, $x);
        $pre_f = index_freq($pre);
        $post_f = index_freq($post);
        if (($pre_f eq 0) and ($post_f eq 0)) {
            next;
        }

        my $preflag = 0;
        my @phrase;

        if ($pre_f > 0 and (length $pre > length $post)) {
            $preflag = 1;
            $phrase[0] = $pre;
        } else {
            $phrase[0] = $post;
        }
        my ($ref, $locref) = execute_query(@phrase);
        my %results = %$ref;
        my %locations = %$locref;
        @sortedResults = reverse sort {$results{$a} <=> $results{$b}} keys %results;
        foreach my $result(@sortedResults){
            my $sum =  get_summary($result, $locations{$result});
            $sum =~ s/\s+/ /g;
            $sum =~ s/[^a-zA-Z0-9- ]//g;
            my @words = split(/\s+/, $sum);
            my $index = first { $words[$_] eq $phrase[0] } 0 .. $#words;
            
            if ($preflag eq 1) {
                my $ph = $words[$index]." ".$words[$index+2];
                my $similar_word = $words[$index+1];
                if ($similar_word eq $w) {
                    next;
                }
                if (($post eq $words[$index+2])) { #and (not exists $duplicates{$ph})) {
#$duplicates{$ph} = 1;
                    if (not exists $similar{$similar_word}) {
                        $similar{$similar_word} = 1;
                    } else {
                        my $c = $similar{$similar_word};
                        $similar{$similar_word} = $c + 1;
                    }
                }
            } else {
                my $ph = $words[$index-2]." ".$words[$index];
                my $similar_word = $words[$index-1];
                if ($similar_word eq $w) {
                    next;
                }
                if (($pre eq $words[$index-2])) { #and (not exists $duplicates{$ph})) {
#$duplicates{$ph} = 1;
                    if (not exists $similar{$similar_word}) {
                        $similar{$similar_word} = 1;
                    } else {
                        my $c = $similar{$similar_word};
                        $similar{$similar_word} = $c + 1;
                    }
                }
            }
        }
    }
    return \%similar;
}

sub get_similar_words{
    my $pattern = @_[0];
    my %context = ();
    
    my ($ref, $locref) = execute_query(@_);
     my %results = %$ref;
     my %locations = %$locref;
     @sortedResults = reverse sort {$results{$a} <=> $results{$b}} keys %results;
     foreach my $result(@sortedResults){
        my $sum =  get_summary($result, $locations{$result});
        $sum =~ s/\s+/ /g;
        $sum =~ s/[^a-zA-Z0-9- ]//g;
        my @words = split(/\s+/, $sum);
        my $index = first { $words[$_] eq $pattern } 0 .. $#words;

        $words[$index-1] =~ s/[^a-zA-Z0-9]*$//g;
        $words[$index+1] =~ s/[^a-zA-Z0-9]*$//g;

        $pre = $words[$index-1];
        $post = $words[$index+1];

        my $context_phrase = $pre." ".$post;
        $context{$context_phrase} = 1 if not exists $context{$context_phrase};
     }
     return produce_similar(\%context, $pattern);
}

1;
