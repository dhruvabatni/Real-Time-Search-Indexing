#!/usr/bin/perl

=pod

=head1 NAME

collection

=head1 SYNOPSIS

collection

=head1 DESCRIPTION

This module provides methods to do basic
processing of a data set before indexing.

=head1 METHODS

B<parse_file>
Returns a hash of all XML elements.

B<process_collection>
Given a path to the collection fo files in XML format, it processes all the files to help with the next step - indexing.

=cut

sub parse_file{
   my $file=shift;
   # create object
   my $xml = new XML::Simple;
   # read XML file
   my $data = $xml->XMLin($file);
   return $data;
}

sub process_collection{
   my ($cranfield_path, $destination) = @_;
   print "parsing xml and storing metadata...\n";
   @files = `ls $source`;
   %title_meta=();
   dbmopen(%title_meta, "titles", 0666);
   %bibl_meta=();
   dbmopen(%bibl_meta, "bibl", 0666);
   %author_meta=();
   dbmopen(%author_meta, "authors", 0666);
   %length=();
   dbmopen(%length, "doclength", 0666);
   if(-d $destination){
      `rm -r $destination`;
   }
  `mkdir $destination`;
   @files = <$cranfield_path/*>;
   foreach my $doc(@files){
       my $hash = parse_file("$doc");
       my $text =  $hash->{"TITLE"} . "\n" . $hash->{"TEXT"}. "\n" . $hash->{"AUTHOR"};
       my $docno = $hash->{"DOCNO"};
       $docno =~ s/[^0-9]*([0-9]+)[^0-9]*/$1/g;
       open (FILE, ">$destination/$docno.txt") or die "Can't create file";
       print FILE $text;
       close (FILE);
       $title_meta{$docno} = $hash->{"TITLE"};
       $author_meta{$docno} = $hash->{"AUTHOR"};
       $text =~ s/\.//g; $text =~ s/,//g;
       my @doclength = split /\s+/, $text;
       $length{$docno} = scalar @doclength;
   }
}

1;
