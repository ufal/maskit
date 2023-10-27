#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use LWP::UserAgent;
use URI::Escape;
use JSON;
use Tree::Simple;
use List::Util qw(min max);
use Getopt::Long; # reading arguments
use POSIX qw(strftime); # naming a file with date and time
use File::Basename;

# STDIN and STDOUT in UTF-8
binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';

my $VER = '0.1'; # version of the program

# default output format
my $OUTPUT_FORMAT_DEFAULT = 'txt';
# default input format
my $INPUT_FORMAT_DEFAULT = 'txt';
# default fake data file name
my $FAKE_DATA_FILE_DEFAULT = 'resources/fake_data.csv';


# variables for arguments
my $input_file;
my $stdin;
my $input_format;
my $fake_data_file;
my $output_format;
my $diff;
my $store_conllu;
my $version;
my $help;

# getting the arguements
GetOptions(
    'i|input-file=s'     => \$input_file, # the name of the input file
    'si|stdin'           => \$stdin, # should the input be read from STDIN?
    'if|input-format=s'  => \$input_format, # input format, possible values: txt, presegmented
    'f|fake-data-file=s' => \$fake_data_file, # the name of the file with a list of fake data
    'of|output-format=s' => \$output_format, # output format, possible values: txt, html, conllu
    'd|diff'             => \$diff, # should the original expressions be displayed next to the anonymized versions?
    'sc|store-conllu'    => \$store_conllu, # should the result be logged as a conllu file?
    'v|version'          => \$version, # print the version of the program and exit
    'h|help'             => \$help, # print a short help and exit
);


my $script_path = $0;  # Získá název spuštěného skriptu s cestou
my $script_dir = dirname($script_path);  # Získá pouze adresář ze získané cesty


if ($version) {
  print "Anonymizer version $VER.\n";
  exit 0;
}

if ($help) {
  print "Anonymizer version $VER.\n";
  my $text = <<'END_TEXT';
Usage: anonymize.pl [options]
options:  -i|--input-file [input text file name]
         -si|--stdin (input text provided via stdin)
         -if|--input-format [input format: txt (default) or presegmented]
          -f|--fake-data-file [fake data file name]
         -of|--output-format [output format: txt (default), html, conllu]
          -d|--diff (display the original expressions next to the anonymized versions)
         -sc|--store-conllu (log the output of UDPipe parser, NameTag and Anonymizer to a CONLL-U file)
          -v|--version (prints the version of the program and ends)
          -h|--help (prints a short help and ends)
END_TEXT
  print $text;
  exit 0;
}

###################################################################################
# Summarize the program arguments to the log (except for --version and --help)
###################################################################################

print STDERR "\n####################################################################\n";

print STDERR "Arguments:\n";

if ($stdin) {
  print STDERR " - input: STDIN\n";
}
elsif ($input_file) {
  print STDERR " - input: file $input_file\n";
}

if (!defined $input_format) {
  print STDERR " - input format: not specified, set to default $INPUT_FORMAT_DEFAULT\n";
  $input_format = $INPUT_FORMAT_DEFAULT;
}
elsif ($input_format !~ /^(txt|presegmented)$/) {
  print STDERR " - input format: unknown ($input_format), set to default $INPUT_FORMAT_DEFAULT\n";
  $input_format = $INPUT_FORMAT_DEFAULT;
}
else {
  print STDERR " - input format: $input_format\n";
}

if (!defined $fake_data_file) {
  print STDERR " - fake data file: not specified, set to default $FAKE_DATA_FILE_DEFAULT\n";
  $fake_data_file = "$script_dir/$FAKE_DATA_FILE_DEFAULT";
}
else {
  print STDERR " - fake data file: $fake_data_file\n";
}

$output_format = lc($output_format) if $output_format;
if (!defined $output_format) {
  print STDERR " - output format: not specified, set to default $OUTPUT_FORMAT_DEFAULT\n";
  $output_format = $OUTPUT_FORMAT_DEFAULT;
}
elsif ($output_format !~ /^(txt|html|conllu)$/) {
  print STDERR " - output format: unknown ($output_format), set to default $OUTPUT_FORMAT_DEFAULT\n";
  $output_format = $OUTPUT_FORMAT_DEFAULT;
}
else {
  print STDERR " - output format: $output_format\n";
}

if ($diff) {
  print STDERR " - display the original expressions next to the anonymized versions)\n";
}

if ($store_conllu) {
  print STDERR " - log output in a conllu file; includes output of udpipe and nametag)\n";
}


print STDERR "\n";

###################################################################################
# Let us first read the file with fake data
###################################################################################

my %class_constraint2replacements; # NameTag class + constraint => replacements separated by |; the class is separated by '_' from the constraint
my %class2constraints; # which constraints does the class require (if any); the individual constraints are separated by '_'; an empty constraint is represented by 'NoConstraint'

print STDERR "Reading fake data from $fake_data_file\n";

open (FAKES, '<:encoding(utf8)', $fake_data_file)
  or die "Could not open file '$fake_data_file' for reading: $!";

my $fakes_count = 0;
while (<FAKES>) {
  chomp(); 
  my $line = $_;
  $line =~ s/#.*$//; # get rid of comments
  next if ($line =~ /^\s*$/); # empty line
  if ($line =~ /^(\S+)\t(\S+)\t(\S+)$/) {
    my $class = $1;
    my $constraint = $2;
    my $replacements = $3;
    $class_constraint2replacements{$class . '_' . $constraint} = $replacements;
    print STDERR "Class $class (with constraint $constraint) and replacements $replacements\n";
    $fakes_count++;
    if ($class2constraints{$class}) { # if there already was a constraint for this class
      print STDERR "Note: multiple constraints for class $class.\n";
      $class2constraints{$class} .= "_";
    }
    $class2constraints{$class} .= $constraint;
  }
  else {
    print STDERR "Unknown format of a line in file $fake_data_file:\n$line\n";
  }
}
print STDERR "$fakes_count fake replacement rules have been read from file $fake_data_file:\n";

close(FAKES);

exit;

###################################################################################
# Now let us read the text file that should be anonymized
###################################################################################

my $input_content;

if ($stdin) { # the input text should be read from STDIN
  $input_content = '';
  while (<>) {
    $input_content .= $_;
  }
  my $current_datetime = strftime("%Y%m%d_%H%M%S", localtime);
  $input_file = "stdin_$current_datetime.txt"; # a fake file name for naming the output files

} elsif ($input_file) { # the input text should be read from a file
  open my $file_handle, '<:encoding(utf8)', $input_file
    or die "Cannot open file '$input_file' for reading: $!";

  $input_content = do { local $/; <$file_handle> }; # reading the file into a variable
  close $file_handle;

} else {
  print STDERR "No input to process! Exiting!\n";
  exit -1;
}

#print STDERR $input_content;


###################################################################################
# Let us parse the file using UDPipe REST API
###################################################################################

my $conll_data = call_udpipe($input_content);

# Store the result to a file (just to have it, not needed for further processing)
#  open(OUT, '>:encoding(utf8)', "$input_file.conll") or die "Cannot open file '$input_file.conll' for writing: $!";
#  print OUT $conll_data;
#  close(OUT);

###################################################################################
# Now let us add info about named entities using NameTag REST API
###################################################################################

my $conll_data_ne = call_nametag($conll_data);

# Store the result to a file (just to have it, not needed for further processing)
#  open(OUT, '>:encoding(utf8)', "$input_file.conllne") or die "Cannot open file '$input_file.conllne' for writing: $!";
#  print OUT $conll_data_ne;
#  close(OUT);



###################################################################################
# Let us parse the CONLL format into Tree::Simple tree structures (one tree per sentence)
###################################################################################

my @lines = split("\n", $conll_data_ne);

my @trees = (); # array of trees in the document

my $root; # a single root

my $min_start = 10000; # from indexes of the tokens, we will get indexes of the sentence
my $max_end = 0;

my $multiword = ''; # store a multiword line to keep with the following token

# the following cycle for reading UD CONLL is modified from Jan Štěpánek's UD TrEd extension
foreach my $line (@lines) {
    chomp($line);
    #print STDERR "Line: $line\n";
    if ($line =~ /^#/ && !$root) {
        $root = Tree::Simple->new({}, Tree::Simple->ROOT);
        #print STDERR "Beginning of a new sentence!\n";
    }

    if ($line =~ /^#\s*newdoc/) { # newdoc
        set_attr($root, 'newdoc', $line); # store the whole line incl. e.g. id = ...
    } elsif ($line =~ /^#\s*newpar/) { # newpar
        set_attr($root, 'newpar', $line); # store the whole line incl. e.g. id = ...
    } elsif ($line =~ /^#\s*sent_id\s=\s*(\S+)/) {
        my $sent_id = $1; # substr $sent_id, 0, 0, 'PML-' if $sent_id =~ /^(?:[0-9]|PML-)/;
        set_attr($root, 'id', $sent_id);
    } elsif ($line =~ /^#\s*text\s*=\s*(.*)/) {
        set_attr($root, 'text', $1);
        #print STDERR "Reading sentence '$1'\n";
    } elsif ($line =~ /^#/) { # other comment, store it as well (all other comments in one attribute other_comment with newlines included)
        my $other_comment_so_far = attr($root, 'other_comment') // '';
        set_attr($root, 'other_comment', $other_comment_so_far . $line . "\n");
        
    } elsif ($line =~ /^$/) { # empty line, i.e. end of a sentence
        _create_structure($root);
        set_attr($root, 'start', $min_start);
        set_attr($root, 'end', $max_end);
        $min_start = $min_start = 10000;
        $max_end = 0;
        push(@trees, $root);
        #print STDERR "End of sentence id='" . attr($root, 'id') . "'.\n\n";
        $root = undef;

    } else { # a token
        my ($n, $form, $lemma, $upos, $xpos, $feats, $head, $deprel,
            $deps, $misc) = split (/\t/, $line);
        $_ eq '_' and undef $_
            for $xpos, $feats, $deps, $misc;

        # $misc = 'Treex::PML::Factory'->createList( [ split /\|/, ($misc // "") ]);
        #if ($n =~ /-/) {
        #    _create_multiword($n, $root, $misc, $form);
        #    next
        #}
        if ($n =~ /-/) { # a multiword line, store it to keep with the next token
          $multiword = $line;
          next;
        }
        
        #$feats = _create_feats($feats);
        #$deps = [ map {
        #    my ($parent, $func) = split /:/;
        #    'Treex::PML::Factory'->createContainer($parent,
        #                                            {func => $func});
        #} split /\|/, ($deps // "") ];

        my $node = Tree::Simple->new({});
        set_attr($node, 'ord', $n);
        set_attr($node, 'form', $form);
        set_attr($node, 'lemma', $lemma);
        set_attr($node, 'deprel', $deprel);
        set_attr($node, 'upostag', $upos);
        set_attr($node, 'xpostag', $xpos);
        set_attr($node, 'feats', $feats);
        set_attr($node, 'deps', $deps); # 'Treex::PML::Factory'->createList($deps),
        set_attr($node, 'misc', $misc);
        set_attr($node, 'head', $head);
        
        if ($multiword) { # the previous line was a multiword, store it at the current token
          set_attr($node, 'multiword', $multiword);
          $multiword = '';
        }
        
        if ($misc and $misc =~ /TokenRange=(\d+):(\d+)\b/) {
          my ($start, $end) = ($1, $2);
          set_attr($node, 'start', $start);
          set_attr($node, 'end', $end);
          $min_start = $start if $start < $min_start;
          $max_end = $end if $end > $max_end;          
        }
        
        $root->addChild($node);
        
    }
}
# If there wasn't an empty line at the end of the file, we need to process the last tree here:
if ($root) {
    _create_structure($root);
    set_attr($root, 'start', $min_start);
    set_attr($root, 'end', $max_end);
    push(@trees, $root);
    #print STDERR "End of sentence id='" . attr($root, 'id') . "'.\n\n";
    $root = undef;
    #warn "Emtpy line missing at the end of input\n";
}
# end of Jan Štěpánek's modified cycle for reading UD CONLL



###########################################################################################
# Now we have dependency trees of the sentences; let us search for phrases to be anonymized
###########################################################################################

# print_log_header();

foreach $root (@trees) {
  print STDERR "\n====================================================================\n";
  print STDERR "Sentence id=" . attr($root, 'id') . ": " . attr($root, 'text') . "\n";
  # print_children($root, "\t");
  
  my @nodes = descendants($root);
  foreach my $node (@nodes) {
    my $lemma = attr($node, 'lemma');
    my $feats = attr($node, 'feats');
    my $ne = get_misc_value($node, 'NE');
    
    
    
    
    
    
    
#´!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
    
    
    
    
    
    
    my $constraints = $phrase_lemma2constraints{$lemma};
    if (!$constraints) {
      print STDERR "No constraints for lemma '$lemma', skipping.\n";
      next; # the lemma is not among citation phrases
    }
    foreach my $constraint (split(/_/, $constraints)) { # split the constraints by separator '_' and work with one constraint at a time
      my $reliability = $phrase_lemma_constraint2reliability{$lemma . '_' . $constraint} // 0;
      print STDERR "Testing phrase lemma (constraint) '$lemma ($constraint)' with reliability $reliability\n";

      my ($claim_parent, @phrase_nodes) = check_constraint($node, $lemma, $constraint); # check if the constraint is met (e.g., se/si is present) and return the expected parent of the claim and all nodes belonging to the phrase; empty constraint is represented by 'NoConstraint'
      if (!$claim_parent) {
        print STDERR "- the constraint '$constraint' for lemma '$lemma' is not met.\n";
        next;
      }
      if ($reliability >= $min_phrase_reliability) {
        print STDERR " - reliability of lemma '$lemma' with constraint '$constraint' is greater than threshold $min_phrase_reliability\n";
        # Checking if there is something like a claim, i.e. a finite-verb core object 
        if (has_finite_verb_object($claim_parent)) {
          evaluate_single_event('phrase', $lemma, $constraint, $root, @phrase_nodes);
          if ($constraint eq 'PREP') { # special treatment of 'podle' and 'dle'
            my $parent = $node->getParent;
            my $source = attr($parent, 'form');
            my @whole_source_nodes = get_whole_source_nodes($parent);
            my $whole_source = get_text(@whole_source_nodes);
            print STDERR " - SOURCE parent: $source\n - WHOLE SOURCE: $whole_source\n";
            my $source_type = guess_source_type($root, $node, @whole_source_nodes);
            print STDERR "   - SOURCE TYPE: $source_type\n";
            evaluate_single_event($source_type, $lemma, 'N/A', $root, @whole_source_nodes);
          }
          else {
            my @nsubj = grep {attr($_, 'deprel') eq 'nsubj'} $node->getAllChildren; # looking for a subject (i.e, the source)
            if (@nsubj) {
              my $subject = attr($nsubj[0], 'form');
              my @whole_source_nodes = get_whole_source_nodes($nsubj[0]);
              my $whole_source = get_text(@whole_source_nodes);
              print STDERR " - SOURCE nsubj: $subject\n - WHOLE SOURCE: $whole_source\n";
              my $source_type = guess_source_type($root, $node, @whole_source_nodes);
              print STDERR "   - SOURCE TYPE: $source_type\n";
              evaluate_single_event($source_type, $lemma, 'N/A', $root, @whole_source_nodes);
            }
          }
        }
        else {
          print STDERR "   - no finite-verb core object found!\n";
        }
      }
    }
  }
  
  
}

# print_log_tail();

# print the input text with marked sources in the selected output format to STDOUT
my $output = get_output($output_format); 
print $output;

if ($store_conllu) { # log the anonymized text in the conllu format in a file
  $output = get_output('conllu') if $output_format ne 'conllu';
  open(OUT, '>:encoding(utf8)', "$script_dir/log/$input_file.conllu") or die "Cannot open file '$script_dir/log/$input_file.conllu' for writing: $!";
  print OUT $output;
  close(OUT);
}

################################################################
########################## FINISHED ############################
################################################################




=item is_finite

Checks if the given node represents a finite verb

=cut

sub is_finite {
  my $node = shift;
  my $VerbForm = get_feat_value($node, 'VerbForm') // '';
  # print STDERR "is_finite: VerbForm = '$VerbForm'\n";
  if ($VerbForm and $VerbForm ne 'Inf') {
    return 1;
  }
  # It may also be a copula ("je konzervativní")
  my @cop_children = grep {attr($_, 'deprel') eq 'cop'} $node->getAllChildren;
  if (@cop_children) {
    if (is_finite($cop_children[0])) {
      return 1;
    }
  }
  # It may be a complex verb ("bude potřebovat")
  my @finverb_children = grep {get_feat_value($_, 'VerbForm') and get_feat_value($_, 'VerbForm') ne 'Inf'} $node->getAllChildren;
  if ($VerbForm and @finverb_children) {
    if (is_finite($finverb_children[0])) {
      return 1;
    }
  }  
  # It may be a reference to a verbal phrase, such as "potvrzuje to i ..." or "jeho slova potvrzuje i ..."
  my $form = attr($node, 'form');
  if ($form =~ /^(slova|to|tom)$/) {
    return 1;
  }
  return 0;
}



=item has_child_with_lemma

Checks if a lemma is among children

=cut

sub has_child_with_lemma {
  my ($node, $lemma) = @_;
  if (grep {attr($_, 'lemma') eq $lemma} $node->getAllChildren) {
    return 1;
  }
  return 0;
}


=item guess_source_type

Guesses and returns the type of the source, i.e. one of these values:

        anonymous
        anonymous-partial
        unofficial
        official-political
        official-non-political

NameTag offers these values:

NE containers

P - complex person names
T - complex time expressions
A - complex address expressions
C - complex bibliographic expressions

Types of NE

a - Numbers in addresses
ah - street numbers
at - phone/fax numbers
az - zip codes

g - Geographical names
gc - states
gh - hydronyms
gl - nature areas / objects
gq - urban parts
gr - territorial names
gs - streets, squares
gt - continents
gu - cities/towns
g_ - underspecified

i - Institutions
ia - conferences/contests
ic - cult./educ./scient. inst.
if - companies, concerns...
io - government/political inst.
i_ - underspecified

m - Media names
me - email address
mi - internet links
mn - periodical
ms - radio and TV stations

n - Number expressions
na - age
nb - vol./page/chap./sec./fig. numbers
nc - cardinal numbers
ni - itemizer
no - ordinal numbers
ns - sport score
n_ - underspecified

o - Artifact names
oa - cultural artifacts (books, movies)
oe - measure units
om - currency units
op - products
or - directives, norms
o_ - underspecified

p - Personal names
pc - inhabitant names
pd - (academic) titles
pf - first names
pm - second names
pp - relig./myth persons
ps - surnames
p_ - underspecified

t - Time expressions
td - days
tf - feasts
th - hours
tm - months
ty - years

=cut



=item get_misc_value

Returns a value of the given property from the misc attribute. Or undef.

=cut

sub get_misc_value {
  my ($node, $property) = @_;
  my $misc = attr($node, 'misc') // '';
  # print STDERR "get_misc_value: misc=$misc\n";
  if ($misc =~ /$property=([^|]+)/) {
    my $value = $1;
    # print STDERR "get_misc_value: $property=$value\n";
    return $value;
  }
  return undef;
}  



=item get_feat_value

Returns a value of the given property from the feats attribute. Or undef.

=cut

sub get_feat_value {
  my ($node, $property) = @_;
  my $feats = attr($node, 'feats') // '';
  # print STDERR "get_feat_value: feats=$feats\n";
  if ($feats =~ /$property=([^|]+)/) {
    my $value = $1;
    # print STDERR "get_feat_value: $property=$value\n";
    return $value;
  }
  return undef;
}  


=item get_output

Returns the input text with marked sources in the given format (one of: txt, html, conllu).

=cut

sub get_output {
  my $format = shift;
  my $output = '';

  # FILE HEADER
  
  if ($format eq 'html') {
    $output .= "<html>\n";
    $output .= "<body>\n";
  }
  
  my $first_par = 1; # for paragraph separation in txt and html formats (first par in the file should not be separated)

  my $first_sent = 1; # for sentence separation in txt and html formats (first sentence in the file should not be separated)

  # for conllu:
  my $SD_phrase_count = 0; # counting citation phrases
  my $SD_source_count = 0; # counting citation sources
  my $SD_count; # for keeping the number of the current event
  my $inside_SD = 0; # for dealing with multi-token events
  my $end_of_SD = 0; # dtto
  my $SD_type = ''; # type of the event - P for phrases, S for sources
  my $SD_subtype = ''; # source type
  
  foreach $root (@trees) {
  
    # PARAGRAPH SEPARATION (txt, html)
    if (attr($root, 'newpar') and $format =~ /^(txt|html)$/) {
      $first_sent = 1;
      if ($first_par) {
        $first_par = 0;
      }
      else {
        $output .= $format eq 'html' ? "\n</p>\n" : "\n\n";
      }
      $output .= "<p>\n" if $format eq 'html';
    }
    
    # SENTENCE HEADER (conllu)
    if ($format eq 'conllu') {
      $output .= attr($root, 'other_comment') // '';
      my $newdoc = attr($root, 'newdoc') // '';
      $output .= "$newdoc\n" if $newdoc;
      my $newpar = attr($root, 'newpar') // '';
      $output .= "$newpar\n" if $newpar;
      my $sent_id = attr($root, 'id') // '';
      $output .= "# sent_id = $sent_id\n" if $sent_id;
      my $text = attr($root, 'text') // '';
      $output .= "# text = $text\n" if $text;
    }

    # sentence separation in txt and html formats
    if ($format =~ /^(txt|html)$/) {
      if ($first_sent) {
        $first_sent = 0;
      }
      else {
        if ($input_format eq 'presegmented') { # each sentence should go to its own line
          $output .= "\n";
          if ($format eq 'html') {
            $output .= '<br>';
          }
        }
        else {
          $output .= ' ';
        }
      }
    }

    # PRINT THE SENTENCE TOKEN BY TOKEN
    my @nodes = sort {attr($a, 'ord') <=> attr($b, 'ord')} descendants($root);
    my $space_before = '';

    foreach my $node (@nodes) {
    
      # COLLECT INFO ABOUT THE TOKEN
      my $form = attr($node, 'form');
      my $start = attr($node, 'start');
      my $end = attr($node, 'end');
      
      my $span_start = '';
      my $span_end = '';
      my $type_span = '';

      my $source_range = partial_match("$start:$end", \%h_source_range2text) // ''; # is this token a part of a source?
      if ($source_range) {
        if ($source_range =~ /^$start:/) { # first token in this source
          $SD_source_count++;
          $SD_count = $SD_source_count;
        }
        if ($source_range =~ /\b$start:/) { # first token in one of contiguous parts of the source
          $span_start = $format eq 'html' ? '<span style="font-weight: bold; text-decoration: underline; color: darkgreen">' : '>>';
          $inside_SD = 1;
          $SD_type = 'S';        
          my $source_type = $h_source_range2type{$source_range};
          if ($source_type) {
            $SD_subtype = 'a' if $source_type =~ /anonymous/;
            $SD_subtype = 'ap' if $source_type =~ /anonymous-partial/;
            $SD_subtype = 'u' if $source_type =~ /unofficial/;
            $SD_subtype = 'op' if $source_type =~ /official-political/;
            $SD_subtype = 'onp' if $source_type =~ /official-non-political/;
          }
        }
        if ($source_range =~ /:$end\b/) { # last token in one of contiguous parts of the source
          $span_end = $format eq 'html' ? '</span>' : '<<';
          $end_of_SD = 1;
        }
        if ($source_range =~ /:$end$/) { # last token of the source
          my $source_type = $h_source_range2type{$source_range};
          if ($source_type) {
            $type_span = $format eq 'html' ? "<span style=\"vertical-align: sub; color: darkblue\">[$source_type]</span>" : "[$source_type]";
          }
        }
      }
      
      else { # it is not a part of a source, maybe it is a part of a phrase?
        my $phrase_range = partial_match("$start:$end", \%h_phrase_range2text) // ''; # is this token a part of a citation phrase?
        if ($phrase_range =~ /^$start:/) { # first token in this phrase
          $SD_phrase_count++;
          $SD_count = $SD_phrase_count;
        }
        if ($phrase_range =~ /\b$start:/) { # first token in one of contiguous parts of the phrase
          $span_start = $format eq 'html' ? '<span style="font-weight: bold; color: darkred">' : '@';
          $inside_SD = 1;
          $SD_type = 'P';        
        }
        if ($phrase_range =~ /:$end\b/) { # last token in one of contiguous parts of the phrase
          $span_end = $format eq 'html' ? '</span>' : '@';
          $end_of_SD = 1;
        }
      }
      
      # PRINT THE TOKEN
      if ($format =~ /^(txt|html)$/) {
        my $SpaceAfter = get_misc_value($node, 'SpaceAfter') // '';
        $output .= "$space_before$span_start$form$span_end$type_span";
        $space_before = $SpaceAfter eq 'No' ? '' : ' '; # this way there will not be space after the last token of the sentence
      }
      elsif ($format eq 'conllu') {
        my $ord = attr($node, 'ord') // '_';
        my $lemma = attr($node, 'lemma') // '_';
        my $deprel = attr($node, 'deprel') // '_';
        my $upostag = attr($node, 'upostag') // '_';
        my $xpostag = attr($node, 'xpostag') // '_';
        my $feats = attr($node, 'feats') // '_';
        my $deps = attr($node, 'deps') // '_';
        my $misc = attr($node, 'misc') // '_';
        
        if ($inside_SD) { # add info to $misc about detected events
          my $event = 'SD=' . $SD_type . '_' . $SD_count;
          $event .= '_' . $SD_subtype if ($SD_subtype);
          
          if ($misc eq '_') {
            $misc = $event;
          }
          else {
            my @miscs = split('\|', $misc);
            push(@miscs, $event);
            my @miscs_sorted = sort {$a cmp $b} @miscs;
            $misc = join('|', @miscs_sorted);
          }
          
          if ($end_of_SD) {
            $inside_SD = 0;
            $end_of_SD = 0;
            $SD_type = '';
            $SD_subtype = '';
          }
        }
        
        my $head = attr($node, 'head') // '_';
        
        my $multiword = attr($node, 'multiword') // '';
        if ($multiword) {
          $output .= "$multiword\n";
        }
        
        $output .= "$ord\t$form\t$lemma\t$upostag\t$xpostag\t$feats\t$head\t$deprel\t$deps\t$misc\n";
      }
    }

    # sentence separation in the conllu format needs to be here (also the last sentence should be ended with \n)
    if ($format eq 'conllu') {
      $output .= "\n"; # an empty line ends a sentence in the conllu format    
    }
    
  }

  if ($format eq 'html') {
    $output .= "\n</p>\n";
    $output .= "</body>\n";
    $output .= "</html>\n";
  }

  return $output;
  
} # get_output



=item get_sentence

Given a range of text indexes (e.g. "124:129"), it returns the sentence to which the range belongs.

=cut

sub get_sentence {
  my $range = shift;
  if ($range =~ /^(\d+):(\d+)/) {
    my ($start, $end) = ($1, $2);
    foreach $root (@trees) { # go through all sentences
      if (attr($root, 'start') <= $start and attr($root, 'end') >= $end) { # we found the tree
        return attr($root, 'text');
      }
    }
  }
  else {
    return 'N/A';
  }
}


=item get_sentence_html

Given two ranges of text indexes (e.g. "124:129"), it returns the sentence to which they belong.
The function uses the first range that is in the correct format and suppose that the other one is either to be omitted or from the same sentence.
Both ranges are marked in the sentence; the first one with bold, the other one with underline.

=cut

sub get_sentence_html {
  my ($range_auto, $range_manual) = @_;

  print STDERR "get_sentence_html: $range_auto, $range_manual\n";
  
  # check if there is auto range given
  my ($start_auto, $end_auto) = (10000, -1);
  if ($range_auto and $range_auto =~ /^(\d+):(\d+)/) {
    ($start_auto, $end_auto) = ($1, $2);
  }

  # check if there is manual range given
  my ($start_manual, $end_manual) = (10000, -1);
  if ($range_manual and $range_manual =~ /^(\d+):(\d+)/) {
    ($start_manual, $end_manual) = ($1, $2);
  }
  
  print STDERR "get_sentence_html:   $start_auto, $end_auto, $start_manual, $end_manual\n";

  if ($end_auto > 0 or $end_manual > 0) { # at least one of the given ranges was properly defined

    my ($start, $end) = $end_auto > 0 ? ($start_auto, $end_auto) : ($start_manual, $end_manual); # for searching for the sentence
    print STDERR "get_sentence_html:     start = $start, end = $end\n";

    foreach $root (@trees) { # go through all sentences
      my ($start_sent, $end_sent) = (attr($root, 'start'), attr($root, 'end'));
      if ($start_sent <= $start and $end_sent >= $end) { # we found the tree
        my $sentence_text = attr($root, 'text');
        my $sentence_html = '';
        for (my $i = 0; $i < length($sentence_text); $i++) {
          if ($start_sent + $i == $start_auto) {
              $sentence_html .= "<b>";
          }
          if ($start_sent + $i == $start_manual) {
              $sentence_html .= "<u>";
          }

          if ($start_sent + $i == $end_manual) {
              $sentence_html .= "</u>";
          }
          if ($start_sent + $i == $end_auto) {
              $sentence_html .= "</b>";
          }
          
          $sentence_html .= substr($sentence_text, $i, 1);
          
        }
        return $sentence_html;
      }
    }
  }
  else {
    return 'N/A';
  }
}



=item get_range

Returns a text index range for an array of nodes
For non-contiguous ranges, the individual contiguous parts are separated by ';'

=cut

sub get_range {
  my @nodes = sort {attr($a, 'start') <=> attr($b, 'start')} @_;
  return '' if !@nodes;
  # print STDERR "get_range: nodes: " . join(' ', map {attr($_, 'form')} @nodes) . "\n";
  my $range = '';
  my $start = shift(@nodes);
  my $end = $start;
  my $prev = $start;
  foreach my $node (@nodes) { # go through the remaining nodes
    if (attr($prev, 'end') + 1 >= attr($node, 'start')) { # the nodes are consequent
      $end = $node;
      $prev = $node;
    }
    else { # there is a gap between $prev and $node
      my $sep = $range ? ';' : '';
      $range .= $sep . attr($start, 'start') . ':' . attr($end, 'end');
      $start = $node;
      $end = $node;
      $prev = $node;
    }
  }
  # now process the last contiguous part
  my $sep = $range ? ';' : '';
  $range .= $sep . attr($start, 'start') . ':' . attr($end, 'end');
  # print STDERR "get_range: result: $range\n";
  return $range;
}


=item get_text

Given an array of nodes, it gives their surface text

=cut

sub get_text {
  my @nodes = @_;
  my @nodes_ordered = sort {attr($a, 'ord') <=> attr($b, 'ord')} @nodes;
  my $text = join(' ', map {attr($_, 'form')} @nodes_ordered);
  return $text;
}


=item get_whole_source

For the given source node, it collects all nodes representing the whole source.

=cut

sub get_whole_source_nodes {
  my $node = shift;
  my @source_nodes = get_source_nodes($node);
  push(@source_nodes, $node);
  return @source_nodes;
}


=item get_source_nodes

It recursively adds sons whith deprel nmod, amod, flat, case (with exception of 'podle') and acl:relcl (acl:relcl with the whole subtree right away)

=cut

sub get_source_nodes {
  my $node = shift;
  
  if (attr($node, 'deprel') eq 'acl:relcl') { # rel. clause, e.g. "lidé, které Radiožurnál oslovil"
    return descendants($node);
  }
  
  my @source_sons = grep {attr($_, 'lemma') ne 'podle'}
                    grep {attr($_, 'deprel') =~ /^(nmod|amod|flat|case|acl:relcl)$/}
                    $node->getAllChildren;
  my @whole_source_nodes = @source_sons;
  foreach my $son (@source_sons) {
    push(@whole_source_nodes, get_source_nodes($son));
  }
  return @whole_source_nodes;
}


# the following function is modified from Jan Štěpánek's UD TrEd extension
sub _create_structure {
    my ($root) = @_;
    my %node_by_ord = map +(attr($_, 'ord') => $_), $root->getAllChildren;
    # print STDERR "_create_structure: \%node_by_ord:\n";
    foreach my $ord (sort {$a <=> $b} keys(%node_by_ord)) {
      # print STDERR "_create_structure:   - $ord: " . attr($node_by_ord{$ord}, 'form') . "\n";
    }
    foreach my $node ($root->getAllChildren) {
        my $head = attr($node, 'head');
        # print STDERR "_create_structure: head $head\n";
        if ($head) { # i.e., head is not 0, meaning this node should not be a child of the technical root
            my $parent = $node->getParent();
            $parent->removeChild($node);
            my $new_parent = $node_by_ord{$head};
            $new_parent->addChild($node);
        }
    }
}

# print children recursively
sub print_children {
    my ($node, $pre) = @_;
    my @children = $node->getAllChildren();
    foreach my $child (@children) {
        my $ord = attr($child, 'ord') // 'no_ord';
        my $form = attr($child, 'form') // 'no_form';
        print STDERR "$ord$pre$form\n";
        print_children($child, $pre . "\t");
    }
}

######### Simple::Tree METHODS #########

sub set_attr {
  my ($node, $attr, $value) = @_;
  my $refha_props = $node->getNodeValue();
  $$refha_props{$attr} = $value;
}

sub attr {
  my ($node, $attr) = @_;
  my $refha_props = $node->getNodeValue();
  return $$refha_props{$attr};
}

sub descendants {
  my $node = shift;
  my @children = $node->getAllChildren;
  foreach my $child ($node->getAllChildren) {
    push (@children, descendants($child));
  }
  return @children;
}
  
sub root {
  my $node = shift;
  while ($node->getParent) {
    $node = $node->getParent;
  }
  return $node;
}


######### PARSING THE TEXT WITH UDPIPE #########

=item call_udpipe

Calling UDPipe REST API; the text to be parsed is passed in the argument
Returns the parsed output in UD CONLL format

=cut

sub call_udpipe {
    my $text = shift;

    # Nastavení URL pro volání REST::API s parametry
    my $tokenizer = 'tokenizer=ranges';
    if ($input_format eq 'presegmented') {
      $tokenizer .= ';presegmented';
    }
    my $url = 'http://lindat.mff.cuni.cz/services/udpipe/api/process?' . $tokenizer . '&tagger&parser&data=' . uri_escape_utf8($text);

    print STDERR "url = $url\n";
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
        # print STDERR "UDPipe result:\n$result\n";
        return $result;
    } else {
        print STDERR "Chyba: " . $res->status_line . "\n";
        return '';
    }
}

######### NAMED ENTITIES WITH NAMETAG #########

=item call_nametag

Calling NameTag REST API; the text to be searched is passed in the argument in UD CONLL format
Returns the text in UD CONLL-NE format.
This function just splits the input conll format to individual sentences (or a few of sentences if $max_sentences is set to a larger number than 1) and calls function call_nametag_part on this part of the input, to avoid the NameTag error caused by a too large argument.

=cut

sub call_nametag {
    my $conll = shift;
    
    my $result = '';
    
    # Let us call NameTag api for each X sentences separately, as too large input produces an error.
    my $max_sentences = 1; # 5 was too large at first attempt, so let us hope 1 is safe enough.
    
    my $conll_part = '';
    my $sent_count = 0;
    foreach my $line (split /\n/, $conll) {
      #print STDERR "Processing line $line\n";
      $conll_part .= $line . "\n";
      if ($line =~ /^\s*$/) { # empty line means end of sentence
        #print STDERR "Found an empty line.\n";
        $sent_count++;
        if ($sent_count eq $max_sentences) {
          $result .= call_nametag_part($conll_part);
          $conll_part = '';
          $sent_count = 0;
        }
      }
    }
    if ($conll_part) { # We need to call NameTag one more time
      $result .= call_nametag_part($conll_part);    
    }
    return $result;
}

=item call_nametag_part

Now actuall calling NameTag REST API for a small part of the input (to avoid error caused by a long argument).
Returns the text in UD CONLL-NE format.
If an error occurs, the function just returns the input conll text unchanged.

=cut

sub call_nametag_part {
    my $conll = shift;

    # Nastavení URL pro volání REST::API s parametry
    my $url = 'http://lindat.mff.cuni.cz/services/nametag/api/recognize?input=conllu&output=conllu-ne&data=' . uri_escape_utf8($conll);

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
        # print STDERR "NameTag result:\n$result\n";
        return $result;
    } else {
        print STDERR "NameTag error: " . $res->status_line . "\n";
        return $conll; 
    }
}
