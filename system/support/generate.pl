#!/usr/bin/perl

# A script to generate all cases for a list of lemmas
# Usage: perl generate.pl [file_name]

use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use LWP::UserAgent;
use URI::Escape;
use JSON;
use Time::HiRes qw(sleep);

# STDIN and STDOUT in UTF-8
binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';

my $file_name = $ARGV[0];
my $output_file_name = "$file_name.out";

##############################################################################################
# We are going to read the file with lists of lemmas and produce its copy with generated lines
##############################################################################################


print STDERR "Reading data from $file_name\n";

open (LEMMAS, '<:encoding(utf8)', $file_name)
  or die "Could not open file '$file_name' for reading: $!";

my $out;
open($out, '>:utf8', "$output_file_name")
  or die "Could not open file '$output_file_name' for writing: $!";


my $count = 0;
while (<LEMMAS>) {
  chomp(); 
  my $line = $_;
  if ($line =~ /^\s*#/) { # copy the comment lines
    print $out "$line\n";
    next;
  }
  if ($line =~ /^\s*$/) { # copy empty lines
    print $out "$line\n";
    next;
  }
  my $line_orig = $line;
  $line =~ s/\s*#.*$//; # get rid of comments at the end of content lines

  if ($line =~ /^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$/) { # a line with class, constraint and '|'-separated list of words in 1st case singular
    my $class = $1;
    my $group = $2;
    my $constraint = $3;
    my $replacements = $4;
    $count++;
    print $out "$line_orig\n"; # the original line with comments if any
    generate($out, $class, $group, $constraint, $replacements);
  }
  else {
    print STDERR "Unknown format of a line in file $file_name:\n$line_orig\n";
  }
}

print STDERR "$count lists of lemmas have been read from file $file_name and processed:\n";

close($out);
close(LEMMAS);

#################
# DONE
#################

sub generate {
  my ($file, $class, $group, $constraint, $replacements) = @_;
  my %lemma2tag = ();
  my @words = split('\|', $replacements);
  foreach my $word (@words) {
    my $output = morphodita_analyze($word);
    print STDERR "generate: Morphodita output for word $word: $output\n";
    my @items = split(/\t/, $output);
    my $token = shift(@items);
    if ($token ne $word) {
      print STDERR "generate: Unmatching word ($word) and token ($token) in Morphodita output $output!\n";
    }
    my $lemma = shift(@items);
    my $tag = shift(@items);
    while ($lemma ne $word or substr($tag, 3, 2) ne 'S1') {
      $lemma = shift(@items);
      $tag = shift(@items);
      last if (!$lemma or !$tag);
    }
    if (!$lemma or !$tag) {
      print STDERR "generate: Could not find suitable lemma ($word) and tag in Morphodita output $output!\n";    
      $tag = ($constraint =~ /Gender=Masc/) ? 'NNMS1-----A----' : 'NNFS1-----A----';
    }
    print STDERR "generate: Lemma $word has tag $tag\n";
    $lemma2tag{$word} = $tag;
  }
  
  my $case_number = 1;
  foreach my $case (qw(Nom Gen Dat Acc Voc Loc Ins)) {
    my $forms = "";
    foreach my $word (@words) {
      my $tag = $lemma2tag{$word};
      substr($tag, 4, 1) = $case_number;
      my $form = get_form($word, $tag);
      $forms .= '|' if ($forms);
      $forms .= $form;
    }
    my $constraint_new = ($constraint eq 'NoConstraint') ? "Case=$case" : "$constraint|Case=$case";
    print $file "$class\t$group\t$constraint_new\t$forms\n";
    $case_number++;
  }
}


sub morphodita_analyze {
  my ($text) = @_;
  sleep(0.1);
  # Nastavení URL pro volání REST::API s parametry
  my $url = 'http://lindat.mff.cuni.cz/services/morphodita/api/analyze?guesser=yes&input=vertical&convert_tagset=strip_lemma_id&output=vertical&data=' . uri_escape_utf8("$text");
  print STDERR "morphodita_analyze: url = $url\n";
  # Vytvoření instance LWP::UserAgent
  my $ua = LWP::UserAgent->new;

  # Vytvoření požadavku
  my $req = HTTP::Request->new('GET', $url);
  $req->header('Content-Type' => 'application/json');

  # Odeslání požadavku a získání odpovědi
  my $res = $ua->request($req);

  # Zkontrolování, zda byla odpověď úspěšná
  if ($res->is_success) {
      # Získání odpovědi v JSON formátu
      my $json_response = decode_json($res->content);
      # Zpracování odpovědi
      my $result = $json_response->{result};
      chomp($result);
      # print STDERR "UDPipe result:\n$result\n";
      return $result;
  } else {
      print STDERR "Chyba: " . $res->status_line . "\n";
      return '';
  }

}




sub get_form {
  my ($lemma, $tag) = @_;
  sleep(0.1);
  # Nastavení URL pro volání REST::API s parametry
  my $url = 'http://lindat.mff.cuni.cz/services/morphodita/api/generate?data=' . uri_escape_utf8("$lemma\t$tag");
  print STDERR "get_form: url = $url\n";
  # Vytvoření instance LWP::UserAgent
  my $ua = LWP::UserAgent->new;

  # Vytvoření požadavku
  my $req = HTTP::Request->new('GET', $url);
  $req->header('Content-Type' => 'application/json');

  # Odeslání požadavku a získání odpovědi
  my $res = $ua->request($req);

  # Zkontrolování, zda byla odpověď úspěšná
  if ($res->is_success) {
      # Získání odpovědi v JSON formátu
      my $json_response = decode_json($res->content);
      # Zpracování odpovědi
      my $result = $json_response->{result};
      chomp($result);
      # print STDERR "UDPipe result:\n$result\n";
      $result =~ s/\t.*$//; # get rid of everything but the form
      return $result;
  } else {
      print STDERR "Chyba: " . $res->status_line . "\n";
      return '';
  }

}



