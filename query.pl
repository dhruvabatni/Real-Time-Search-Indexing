#!/usr/bin/perl 
=head1 NAME

Miscelleneous functions

=head1 DESCRIPTION

Documentation about functions used to implement spell check in queries.

=head2 Methods

=over 12

=item C<frequency>
:: Helper function. It compares the frequency of 2 words in the index. Returns 1 if one word is 50% more frequent than other. Else returns 0.

=item C<handle_queries_with_intelligence>
:: It keeps track of the "previous query" and checks the edit distance with the current query. It it is <=3 and frequency of current word is 50% more than the previous query word, then it records the pair of words in a hash table. For every query it checks whether the word has a hash table entry and suggests the correct spelling to the user.

=back

=head1 AUTHOR

Dhruva L Batni, dlb2155@columbia.edu

=cut 

use IR;
use Time::HiRes qw(gettimeofday);
use WagnerFischer qw(distance);

sub handle_request{
    $query = shift;
    my @request =();
    my $rev = 0;

    while ($query =~ s/\"(.+?)\"//){
        push(@request, $1);
        $rev = 1;
    }
    push(@request, split(/\s+/, $query));
    if ($rev eq 1) {
        @request = reverse @request;
    }

    my $valid = 0;
    if ($request[0] eq "df") {
        $f = document_freq($request[1]);
        print "Num of documents in which \"".$request[1]."\" appears: ".$f."\n";
        $valid = 1;
    } elsif ($request[0] eq "freq") {
        $f = index_freq($request[1]);
        print "Num of times \"".$request[1]."\" appears in the index: ".$f."\n";
        $valid = 1;
    } elsif ($request[0] eq "doc") {
        $text = document_text($request[1]);
        print "Contents of doc ".$request[1].":\n\n";
        print $text;
        $valid = 1;
    } elsif ($request[0] eq "tf") {
        $f = document_term_freq($request[1], $request[2]);
        print "Num of times ".$request[2]." appears in the document ".$request[1].": ".$f."\n";
        $valid = 1;
    } elsif ($request[0] eq "title") {
        $title = get_document_title($request[1]);
        print "Title of the document ".$request[1].": ".$title."\n";
        $valid = 1;
    } elsif ($request[0] eq "similar") {
        $t1 = gettimeofday();
        $z = get_similar_words($request[1]);
        $t2 = gettimeofday();
        $t3 = $t2 - $t1;
        %similar = %$z;
        $c = 0;
        print "\n---------------------------------------------------------------------\n";
        print "Ordered list of words similar in context to [ $request[1] ]\n";
        print "Total time taken for query: $t3 seconds.\n";
        print "---------------------------------------------------------------------\n";
        print "\nOutput 10 entries at a time. Press 'q' to quit or Enter for next page\n";
        print "------------------------------------------------------------------------\n\n";
        foreach $x (reverse sort {$similar{$a} <=> $similar{$b}} keys %similar) {
            if ($x =~ /[^0-9]+/) {
                print $x."\n";
                $c = $c + 1;
                if ($c%10 eq 0) {
                    $next = <>;
                    if ($next eq "q\n") {
                        last;
                    }
                }
            }
        }
        $valid = 1;
    }
    if ($valid) {
        print "\n>";
        return 1;
    }
    return 0;
}

$opt = @ARGV[0];
if ($opt eq "--intelligence") {
    <>;
    handle_queries_with_intelligence();
} else {
    print "Enter your query or type q to quit\n>";
    my $query= <>;
    while ($query ne "q\n"){ 
        if (!handle_request($query)) {
            my @searchTerms =();  
            while ($query =~ s/!\"(.+?)\"//){
                push(@searchTerms, "!".$1);
            }
            while ($query =~ s/\"(.+?)\"//){
                push(@searchTerms, $1);
            }
            push(@searchTerms, split(/\s+/, $query));
            my $t1 = gettimeofday();
            my ($ref, $locref) = execute_query_real_time(@searchTerms);
            my $t2 = gettimeofday();
            my $t3 = $t2 - $t1;
            my %results = %$ref;
            my %locations = %$locref;
            @sortedResults = reverse sort {$results{$a} <=> $results{$b}} keys %results;
            $c = 2;
            print "\n--------------------------------------------------------------------------------------\n";
            print "Query processed in $t3 seconds\n";
            print "----------------------------------------------------------------------------------------\n";
            print "\nOutput 10 entries at a time. Press 'q' to quit or Enter for next page\n";
            print "----------------------------------------------------------------------------------------\n\n";
            foreach my $result(@sortedResults){
                my $sum =  get_summary($result, $locations{$result});
                print "Doc: $result  \tScore: $results{$result}\t$sum\n"; 
                $c = $c + 1;
                if ($c%10 eq 0) {
                    $next = <>;
                    if ($next eq "q\n") {
                        last;
                    }
                }
            }
            print "\n>";
        }
        $query=<>;
    }
}

sub frequency{

    my $prev = shift;
    my $q = shift;

    if ($prev eq "") {
        return 0;
    }
    my $prev_if = index_freq($prev);
    my $q_if = index_freq($q);

    if ($q_if eq 0) {return 0;}
    if (($prev_if / $q_if ) <= 0.5) {
        return 1;
    } 
    return 0;
}

sub handle_queries_with_intelligence{
    my %spell_check = ();
    my $prev = "";
    print "Enter your query or type q to quit\n>";
    my $query;
    chomp ($query= <>);
    if (not ($query =~ m/ / or $query[0] eq '!')) {
        $prev = $query;
    }
    while ($query ne "q"){ 
        if (!handle_request($query)) {
            my @searchTerms =();  
            while ($query =~ s/!\"(.+?)\"//){
                push(@searchTerms, "!".$1);
            }
            while ($query =~ s/\"(.+?)\"//){
                push(@searchTerms, $1);
            }
            push(@searchTerms, split(/\s+/, $query));
            my $t1 = gettimeofday();
            my ($ref, $locref) = execute_query_real_time(@searchTerms);
            my $t2 = gettimeofday();
            my $t3 = $t2 - $t1;
            my %results = %$ref;
            my %locations = %$locref;
            @sortedResults = reverse sort {$results{$a} <=> $results{$b}} keys %results;
            $c = 2;
            print "\n--------------------------------------------------------------------------------------\n";
            print "Query processed in $t3 seconds\n";
            if (exists $spell_check{$query}) {
                $term = $spell_check{$query};
                print "\nDid you mean : $term"."?\n";
            }
            print "----------------------------------------------------------------------------------------\n";
            print "\nOutput 10 entries at a time. Press 'q' to quit or Enter for next page\n";
            print "----------------------------------------------------------------------------------------\n\n";
            foreach my $result(@sortedResults){
                my $sum =  get_summary($result, $locations{$result});
                print "Doc: $result  \tScore: $results{$result}\t$sum\n"; 
                $c = $c + 1;
                if ($c%10 eq 0) {
                    $next = <>;
                    if ($next eq "q\n") {
                        last;
                    }
                }
            }
            print "\n>";
        }
        chomp ($query=<>);
        $tmp = $query;
        if (distance($prev, $tmp) <= 3) {
            if ((not ($tmp =~ m/ / or $tmp[0] eq '!')) and frequency($prev, $tmp)) {
                $spell_check{$prev} = $tmp;
            }
        }
        if (not ($tmp =~ m/ / or $tmp[0] eq '!')) {
            $prev = $tmp;
        }
    }
}
