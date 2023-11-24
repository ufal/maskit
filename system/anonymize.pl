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
binmode STDERR, ':encoding(UTF-8)';

my $VER = '0.1 20231124'; # version of the program

#############################
# Colours for html

my $color_replacement_text = 'darkred'; # general replacement colour

# NameTag-class specific replacement colours
my $color_replacement_gu = 'orange'; # town/city
my $color_replacement_gq = 'orange'; # urban parts
my $color_replacement_gs = 'magenta'; # street name
my $color_replacement_ah = 'magenta'; # street number
my $color_replacement_az = 'magenta'; # zip code
my $color_replacement_pf = 'red'; # first name
my $color_replacement_ps = 'red'; # surname
my $color_replacement_me = 'pink'; # e-mail
my $color_replacement_if = 'darkcyan'; # company
my $color_replacement_nk = 'blue'; # IČO
my $color_replacement_nl = 'blue'; # DIČ

# info text colours
my $color_orig_text = 'darkgreen';
my $color_source_brackets = 'darkblue';


#######################################


# default output format
my $OUTPUT_FORMAT_DEFAULT = 'txt';
# default input format
my $INPUT_FORMAT_DEFAULT = 'txt';
# default replacements file name
my $REPLACEMENTS_FILE_DEFAULT = 'resources/replacements.csv';


# variables for arguments
my $input_file;
my $stdin;
my $input_format;
my $replacements_file;
my $output_format;
my $diff;
my $add_NE;
my $store_format;
my $version;
my $help;

# getting the arguements
GetOptions(
    'i|input-file=s'         => \$input_file, # the name of the input file
    'si|stdin'               => \$stdin, # should the input be read from STDIN?
    'if|input-format=s'      => \$input_format, # input format, possible values: txt, presegmented
    'rf|replacements-file=s' => \$replacements_file, # the name of the file with replacements
    'of|output-format=s'     => \$output_format, # output format, possible values: txt, html, conllu
    'd|diff'                 => \$diff, # display the original expressions next to the anonymized versions
    'ne|named-entities=s'    => \$add_NE, # add named entities as marked by NameTag (1: to the anonymized versions, 2: to all recognized tokens)
    'sf|store-format=s'      => \$store_format, # log the result in the given format: txt, html, conllu
    'v|version'              => \$version, # print the version of the program and exit
    'h|help'                 => \$help, # print a short help and exit
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
         -rf|--replacements-file [replacements file name]
         -of|--output-format [output format: txt (default), html, conllu]
          -d|--diff (display the original expressions next to the anonymized versions)
         -ne|--named-entities [scope: 1 - add NameTag marks to the anonymized versions, 2 - to all recognized tokens]
         -sf|--store-format [format: log the output in the given format: txt, html, conllu]
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

if (!defined $replacements_file) {
  print STDERR " - replacements file: not specified, set to default $REPLACEMENTS_FILE_DEFAULT\n";
  $replacements_file = "$script_dir/$REPLACEMENTS_FILE_DEFAULT";
}
else {
  print STDERR " - replacements file: $replacements_file\n";
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
  print STDERR " - display the original expressions next to the anonymized versions\n";
}

if ($add_NE) {
  if ($add_NE == 1) {
    print STDERR " - add named entities as marked by NameTag to the anonymized versions\n";
  }
  elsif ($add_NE == 2) {
    print STDERR " - add named entities as marked by NameTag to all recognized tokens\n";  
  }
  else {
    print STDERR " - unknown value of -ne/--named-entities parameter ($add_NE); no NameTag marks will be printed\n";    
  }
}

$store_format = lc($store_format) if $store_format;
if ($store_format) {
  if ($store_format =~ /^(txt|html|conllu)$/) {
    print STDERR " - log the output to a file in $store_format\n";
  }
  else {
    print STDERR " - unknown format for logging the output ($store_format); the output will not be logged\n";
    $store_format = undef;
  }
}


print STDERR "\n";

###################################################################################
# Let us first read the file with replacements
###################################################################################

my %class_constraint2replacements; # NameTag class + constraint => replacements separated by |; the class is separated by '_' from the constraint
my %class_constraint2group; # grouping e.g. first names across cases and surnames across cases and genders together
my %class2constraints; # which constraints does the class require (if any); the individual constraints are separated by '_'; an empty constraint is represented by 'NoConstraint'

print STDERR "Reading replacements from $replacements_file\n";

open (REPLACEMENTS, '<:encoding(utf8)', $replacements_file)
  or die "Could not open file '$replacements_file' for reading: $!";

my $replacements_count = 0;
while (<REPLACEMENTS>) {
  chomp(); 
  my $line = $_;
  $line =~ s/#.*$//; # get rid of comments
  next if ($line =~ /^\s*$/); # empty line
  if ($line =~ /^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$/) {
    my $class = $1;
    my $group = $2;
    my $constraint = $3;
    my $replacements = $4;
    $class_constraint2replacements{$class . '_' . $constraint} = $replacements;
    $class_constraint2group{$class . '_' . $constraint} = $group;
    print STDERR "Class $class with constraint $constraint, group $group and replacements $replacements\n";
    $replacements_count++;
    if ($class2constraints{$class}) { # if there already was a constraint for this class
      print STDERR "Note: multiple constraints for class $class.\n";
      $class2constraints{$class} .= "_";
    }
    $class2constraints{$class} .= $constraint;
  }
  else {
    print STDERR "Unknown format of a line in file $replacements_file:\n$line\n";
  }
}
print STDERR "$replacements_count replacement rules have been read from file $replacements_file:\n";

close(REPLACEMENTS);


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


############################################################################################
# Let us tokenize and segmet the file using UDPipe REST API with PDT-C 1.0 model
# This model is better for segmentation of texts with many dots in the middle of sentences.
############################################################################################

my $conll_segmented = call_udpipe($input_content, 'segment');

####################################################################################
# Let us parse the tokenized and segmented text using UDPipe REST API with UD model
# With this model I get UD trees and attributes.
####################################################################################

my $conll_data = call_udpipe($conll_segmented, 'parse');

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

my %group2next_index = ();

my %group_stem2index = (); # a hash keeping info about stems and their replacement index (group . '_' . stem -> replacement index)
                           # this way I know that Nezbeda, Nezbedová, Nezbedovou etc. (group 'surname', stem 'Nezbed') belong together

# print_log_header();

foreach $root (@trees) {
  print STDERR "\n====================================================================\n";
  print STDERR "Sentence id=" . attr($root, 'id') . ": " . attr($root, 'text') . "\n";
  # print_children($root, "\t");
  
  my @nodes = descendants($root);
  foreach my $node (@nodes) {
    my $lemma = attr($node, 'lemma') // '';
    my $tag = attr($node, 'xpostag') // '';
    my $form = attr($node, 'form') // '';
    my $feats = attr($node, 'feats') // '';
    my $classes = get_NameTag_marks($node) // '';

    print STDERR "\nProcessing form '$form' with NameTag classes '$classes' and feats '$feats'\n";
    
    next if !$classes; # no NameTag class found here
    
    foreach my $class (split('~', $classes)) {
    
      my $constraints = $class2constraints{$class};
      if (!$constraints) {
        print STDERR "No constraints for NE class '$class', skipping.\n";
        next;
      }
      print STDERR "Found constraints '$constraints' for NE class '$class'\n";

      foreach my $constraint (split(/_/, $constraints)) { # split the constraints by separator '_' and work with one constraint at a time

        my $matches = check_constraint($node, $form, $constraint); # check if the constraint is met (e.g., Gender=Fem); empty constraint is represented by 'NoConstraint'
        if (!$matches) {
          print STDERR " - the constraint '$constraint' for form '$form' is not met.\n";
          next;
        }
        print STDERR " - the constraint '$constraint' for form '$form' matches.\n";
        my $replacement = get_replacement($node, $class, $constraint);
        print STDERR "    - replacement in class $class: '$form' -> '$replacement'\n";
        set_attr($node, 'replacement', $replacement);
        last;
      }
    }
  }  
}

# print_log_tail();

# print the input text with replacements in the selected output format to STDOUT
my $output = get_output($output_format); 
print $output;

if ($store_format) { # log the anonymized text in the given format in a file
  $output = get_output($store_format) if $store_format ne $output_format;
  my $output_file = basename($input_file);
  open(OUT, '>:encoding(utf8)', "$script_dir/log/$output_file.$store_format") or die "Cannot open file '$script_dir/log/$output_file.$store_format' for writing: $!";
  print OUT $output;
  close(OUT);
}

################################################################
########################## FINISHED ############################
################################################################


=item check_constraint

Check if the constraint is met at the node.

The constraint is a sequence of morphological properties from UD attribute feats, e.g.:
Gender=Masc|Number=Sing

Returns 0 if the constraint (all parts) is not met.
Otherwise returns 1.

=cut


sub check_constraint {
  my ($node, $form, $constraint) = @_;

  if ($constraint eq 'NoConstraint') { # no constraint, i.e. trivially matched
    print STDERR " - no constraint, i.e. trivially matched\n";
    return 1;
  }

  my $feats = attr($node, 'feats') // '';
  print STDERR "check_constraint: checking constraint '$constraint' against feats '$feats'\n";

  my @a_constraints = split('\|', $constraint); # get the individul features
  foreach my $feature (@a_constraints) {
    print STDERR " - checking if '$feature' matches\n";
    if ($feats !~ /\b$feature\b/) { # $feature not in $feats
      print STDERR "   - constraint $feature not matching; returning 0\n";
      return 0;
    }
    print STDERR "   - constraint $feature not matches\n";
  }
  print STDERR " - OK, all features matched, the constraint matches.\n";
  return 1;
}

=item get_NameTag_marks

Get a list of NameTag marks assigned to the given node; the return value is a string of the marks divided by '~'.
Fake marks are assigned for cases not recognized by NameTag:

ax - the first part (three digits) of a ZIP code
ay - the second part (two digits) of a ZIP code

nc - IČO

=cut

sub get_NameTag_marks {
  my $node = shift;
  my @values = get_NE_values($node);
  my $marks = join '~', @values;
  # print STDERR "get_NameTag_marks: $ne -> $marks\n";

  my $lemma = attr($node, 'lemma') // '';
  if ($lemma eq '.') { # '.' in e.g. 'ul.' or 'nám.'
    return undef;
  }
  if ($lemma eq 'ulice') {
    return undef;
  }
  if ($lemma eq 'číslo' or $lemma eq 'č') {
    return undef;
  }
  if ($lemma eq '/') { # '/' in e.g. 'Jiráskova 854/3'
    return undef;
  }
  # ZIP codes
  if ($lemma =~ /^[1-9][0-9][0-9]$/ and $marks =~ /\ba[zt]\b/) { # looks like the first part of a ZIP code
    my @ZIP2_children = grep {attr($_, 'lemma') =~ /^[0-9][0-9]$/ and get_NameTag_marks($_) eq 'ay' } $node->getAllChildren;
    if (scalar(@ZIP2_children) == 1) { # it really looks like a ZIP code
      return 'ax'; # a fake class for the first part of a ZIP code
    }
  }
  if ($lemma =~ /^[0-9][0-9]$/ and $marks =~ /\ba[zt]\b/) { # looks like the second part of a ZIP code
    my $parent = $node->getParent;
    my $parent_lemma = attr($parent, 'lemma') // '';
    my $parent_ne = get_misc_value($parent, 'NE') // '';
    my @parent_values = $parent_ne =~ /([A-Za-z][a-z_]?)_[0-9]+/g;
    my $parent_marks = join '~', @parent_values;
    if ($parent_lemma =~ /^[1-9][0-9][0-9]$/ and $parent_marks=~ /\ba[zt]\b/) { # the parent looks like the first part of a ZIP code
      return 'ay'; # a fake mark for the second part of a ZIP code
    }
  }
  
  # IČO
  if (is_ICO($node)) {
    return 'nk'; # fake mark for IČO
  }

  # DIČ
  if (is_DIC($node)) {
    return 'nl'; # fake mark for DIČ
  }

  # Street name
  if (is_street_name($node)) {
    if ($marks !~ /\bgs\b/) { # looks like a street name but was not recognized by NameTag
      if (!$marks) { # nothing was recognized by NameTag
        return 'gs'; # street/square
      }
      else {
        $marks .= '~gs';
      }
    }
  }

  # Urban part
  if (is_urban_part($node)) {
    if ($marks !~ /\bgq\b/) { # looks like a street name but was not recognized by NameTag
      if (!$marks) { # nothing was recognized by NameTag
        return 'gq'; # street/square
      }
      else {
        $marks .= '~gq';
      }
    }
  }

  if (!$marks) {
    return undef;
  }
  return $marks;
}


=item 

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


=item get_NE_values

Returns an array of NameTag marks assigned to the given node in attribute misc

=cut

sub get_NE_values {
  my $node = shift;
  my $ne = get_misc_value($node, 'NE') // '';
  my @values = ();
  if ($ne) {
    @values = $ne =~ /([A-Za-z][a-z_]?)_[0-9]+/g; # get an array of the classes
  }
  return @values;
}

=item

Returns 1 if the given node appears to be an IČO. Otherwise returns 0.
Technically, it returns 1 if:
- either the node represents an 8-digit number
- or it is a number of length 1-8 and its parent is 'IČO' or 'IČ' (also 'ICO' and 'IC')

=cut

sub is_ICO {
  my $node = shift;
  my $form = attr($node, 'form');
  if ($form =~ /^\d{8}$/) { # eight digits
    return 1;
  }
  if ($form =~ /^\d{1,8}$/) { # max eight digits
    my $parent = $node->getParent;
    my $parent_lemma = attr($parent, 'lemma') // '';
    if ($parent_lemma =~ /^I[ČC](O)?$/) {
      return 1;
    }
  }
  return 0;
}


=item

Returns 1 if the given node appears to be a DIČ (VAT ID). Otherwise returns 0.
Technically, it returns 1 if:
- either the node represents an 8-12 digit number preceded by two capital letters
- or it is a number of length 2-12 (optionally preceded by preceded by two capital letters) and its parent is 'DIČ' (also 'DIC')

=cut

sub is_DIC {
  my $node = shift;
  my $form = attr($node, 'form');
  if ($form =~ /^[A-Z][A-Z]\d{8,12}$/) { # two capital letters and eight to twelve digits
    return 1;
  }
  if ($form =~ /^([A-Z][A-Z])?\d{2,12}$/) { # optionally two capital letters and two to twelve digits
    my $parent = $node->getParent;
    my $parent_lemma = attr($parent, 'lemma') // '';
    if ($parent_lemma =~ /^DI[ČC]$/) {
      return 1;
    }
  }
  return 0;
}


=item

Returns 1 if the given node appears to be an urban part (numeric or string). Otherwise returns 0.
Technically, it returns 1 if:
- the form is a number or (starts with a capital letter and and it is an adjective or a noun (incl. a proper noun))
- and NameTag did not assign any g-mark to it
- the parent has 'gu' mark

=cut

sub is_urban_part {
  my $node = shift;
  my $form = attr($node, 'form');
  my $upostag = attr($node, 'upostag');
  if ($form =~ /^\d{1,2}$/ or ($form =~ /^\p{Upper}/ and $upostag =~ /^(ADJ|NOUN|PROPN)$/)) { # is a 1 or 2-digit number or starts with a capital letter and is a noun/adjective
    my @nametag_g_marks = grep {/^g/} get_NE_values($node);
    if (!scalar(@nametag_g_marks)) { # no g-mark assigned to the node
      my $parent = $node->getParent;
      my @nametag_gu_marks = grep {/gu/} get_NE_values($parent);
      if (@nametag_gu_marks) {
        return 1;
      }
    }
  }
  return 0;
}


=item

Returns 1 if the given node appears to be a name of a street. Otherwise returns 0.
Technically, it returns 1 if:
- the form starts with a capital letter
- and it is an adjective or a noun (incl. a proper noun)
- and NameTag did not assign any g-mark to it (because also town may depend on 'ulice', e.g. in "ulice Kralická v Prostějově"
- and the lemma of the parent is 'ulice'

=cut

sub is_street_name {
  my $node = shift;
  my $form = attr($node, 'form');
  my $upostag = attr($node, 'upostag');
  if ($form =~ /^\p{Upper}/ and $upostag =~ /^(ADJ|NOUN|PROPN)$/) { # starts with a capital letter and is a noun/adjective
    my @nametag_g_marks = grep {/^g/} get_NE_values($node);
    if (!scalar(@nametag_g_marks)) { # no g-mark assigned to the node
      my $parent = $node->getParent;
      my $parent_lemma = attr($parent, 'lemma') // '';
      if ($parent_lemma =~ /^ulice$/) {
        return 1;
      }
    }
  }
  return 0;
}


sub get_replacement {
  my ($node, $class, $constraint) = @_;

  my $lemma = attr($node, 'lemma') // '';
  my $form = attr($node, 'form') // '';
  my $stem = get_stem_from_lemma($lemma);

=item

  # check if this lemma with this NameTag class has already been replaced
  my $replacement = $replaced{$class . '_' . $lemma};
  if ($replacement) {
    return $replacement;
  }

=cut

  my $class_constraint = $class . '_' . $constraint;
  my $replacements = $class_constraint2replacements{$class_constraint};
  if (!$replacements) {
    print STDERR "No replacements for NE class '$class' and constraint '$constraint', skipping.\n";
    next;
  }
  print STDERR "  - found replacements '$replacements' for class '$class' and constraint '$constraint'\n";
  my @a_replacements = split('\|', $replacements);
  my $group = $class_constraint2group{$class_constraint};
  
  my $replacement;
  # check if this stem in this group has already been replaced
  my $replacement_index = $group_stem2index{$group . '_' . $stem};
  if (defined($replacement_index)) {
    print STDERR "get_replacement: Found a previously assigned replacement index for group $group and stem $stem: $replacement_index\n";
    my $number_of_replacements = scalar(@a_replacements);
    if ($replacement_index >= $number_of_replacements) { # maximum index exceeded
      $replacement = '[' . $class . '_#' . $replacement_index . ']';
      print STDERR "    - maximum replacement index $number_of_replacements exceeded by requested index $replacement_index!\n";
    }
    else {
      $replacement = $a_replacements[$replacement_index];
    }
  }
  my $new = 0;
  while (!defined($replacement_index)) { # this stem within this group has not yet been seen, so use a new index
    print STDERR "get_replacement: Unseen group $group and stem $stem, assigning a new replacement index\n";
    $replacement_index = $group2next_index{$group} // 0;
    $group2next_index{$group}++;
    $new = 1;
    my $number_of_replacements = scalar(@a_replacements);
    if ($replacement_index >= $number_of_replacements) { # maximum index exceeded
      $replacement = '[' . $class . '_#' . $replacement_index . ']';
      print STDERR "    - maximum replacement index $number_of_replacements exceeded by requested index $replacement_index!\n";
    }
    else {
      $replacement = $a_replacements[$replacement_index];
      if ($replacement eq $form) { # the replacement is accidentally equal to the original form (e.g., Praze vs. Praze); let us skip this replacement index
        print STDERR "    - the replacement is equal to the original form ($form); let us skip this replacement index ($replacement_index)\n";
        $replacement_index = undef; # run the while cycle one more time to use the next replacement index
      }
    }
  }
  if ($new) { # let us store the index for this stem with this group
    print STDERR "get_replacement: Storing a newly assigned replacement index ($replacement_index) for group $group and stem $stem\n";
    $group_stem2index{$group . '_' . $stem} = $replacement_index;
  }
  return $replacement;
}


sub get_stem_from_lemma {
  my $lemma = shift;
  $lemma =~ s/ová$//; # Sedláčková (Sedláček), but also Vondrušková (Vondruška)
  $lemma =~ s/á$//; # Mírovská
  $lemma =~ s/ý$//; # Mírovský
  $lemma =~ s/í$//; # Krejčí
  $lemma =~ s/a$//; # Vondruška (Vondrušková), Svoboda (Svobodová)
  $lemma =~ s/[rlkšs]$//; # Sedláček (Sedláčková), Orel (Orlová), Burger (Burgrová), Lukeš (Lukšová) etc.
  $lemma =~ s/e$//; # cont.
  return $lemma;
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
    $output .= <<END_OUTPUT_HEAD;
<head>
  <style>
        /* source classes colours */
        .replacement-text {
            color: $color_replacement_text;
            text-decoration: underline;
            font-weight: bold
        }
        .replacement-text-gu {
            color: $color_replacement_gu;
        }
        .replacement-text-gq {
            color: $color_replacement_gq;
        }
        .replacement-text-gs {
            color: $color_replacement_gs;
        }
        .replacement-text-ah {
            color: $color_replacement_ah;
        }
        .replacement-text-az {
            color: $color_replacement_az;
        }
        .replacement-text-pf {
            color: $color_replacement_pf;
        }
        .replacement-text-ps {
            color: $color_replacement_ps;
        }
        .replacement-text-me {
            color: $color_replacement_me;
        }
        .replacement-text-if {
            color: $color_replacement_if;
        }
        .replacement-text-nk {
            color: $color_replacement_nk;
        }
        .replacement-text-nl {
            color: $color_replacement_nl;
        }
        .orig-text {
            color: $color_orig_text;
            text-decoration: line-through;
        }
        .orig-brackets {
            color: $color_source_brackets;
            vertical-align: sub;
        }
  </style>
</head>
END_OUTPUT_HEAD
    $output .= "<body>\n";
  }
  
  my $first_par = 1; # for paragraph separation in txt and html formats (first par in the file should not be separated)

  my $first_sent = 1; # for sentence separation in txt and html formats (first sentence in the file should not be separated)

=item

  # for conllu:
  my $SD_phrase_count = 0; # counting citation phrases
  my $SD_source_count = 0; # counting citation sources
  my $SD_count; # for keeping the number of the current event
  my $inside_SD = 0; # for dealing with multi-token events
  my $end_of_SD = 0; # dtto
  my $SD_type = ''; # type of the event - P for phrases, S for sources
  my $SD_subtype = ''; # source type

=cut

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
      my $replacement = attr($node, 'replacement');
      my $form = $replacement // attr($node, 'form');
      my $classes = get_NameTag_marks($node);

      my $span_start = '';
      my $span_end = '';
      my $info_span = '';

      if ($replacement and $format eq 'html') {
        my $span_class = 'replacement-text';
        $span_class .= ' replacement-text-gu' if ($classes =~/\bgu\b/);
        $span_class .= ' replacement-text-gq' if ($classes =~/\bgq\b/);
        $span_class .= ' replacement-text-gs' if ($classes =~/\bgs\b/);
        $span_class .= ' replacement-text-ah' if ($classes =~/\bah\b/);
        $span_class .= ' replacement-text-az' if ($classes =~/\ba[xyz]\b/);
        $span_class .= ' replacement-text-pf' if ($classes =~/\bpf\b/);
        $span_class .= ' replacement-text-ps' if ($classes =~/\bps\b/);
        $span_class .= ' replacement-text-me' if ($classes =~/\bme\b/);
        $span_class .= ' replacement-text-if' if ($classes =~/\bif\b/);
        $span_class .= ' replacement-text-nk' if ($classes =~/\bnk\b/);
        $span_class .= ' replacement-text-nl' if ($classes =~/\bnl\b/);
        $span_start = "<span class=\"$span_class\">";
        $span_end = '</span>';
      }
      
      if (($diff and $replacement) or ($add_NE and $classes and $replacement) or ($add_NE == 2 and $classes)) { # should the original form and/or NE class be displayed as well?
        if ($format eq 'txt') {
          $info_span = '_[';
        }
        elsif ($format eq 'html') {
          $info_span = '<span class="orig-brackets">[';
        }
        if ($add_NE and $classes) {
          $info_span .= $classes;
          $info_span .= '/' if ($diff and $replacement);
        }
        if ($diff and $replacement) {
          if ($format eq 'html') {
            $info_span .= '<span class="orig-text">';
          }
          $info_span .= attr($node, 'form');
          if ($format eq 'html') {
            $info_span .= '</span>';
          }
        }
        if ($format eq 'txt') {
          $info_span .= ']';
        }
        elsif ($format eq 'html') {
          $info_span .= ']</span>';
        }
      }

      
      # PRINT THE TOKEN
      if ($format =~ /^(txt|html)$/) {
        my $SpaceAfter = get_misc_value($node, 'SpaceAfter') // '';
        $output .= "$space_before$span_start$form$span_end$info_span";
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

=item

sub get_form {
  my ($lemma, $tag) = @_;

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

=cut


######### PARSING THE TEXT WITH UDPIPE #########

=item call_udpipe

Calling UDPipe REST API; the input to be processed is passed in the first argument
The second argument ('segment'/'parse') chooses between the two tasks.
Segmentation expects plain text as input, the parsing expects segmented conll-u data.
Returns the output in UD CONLL format

=cut

sub call_udpipe {
    my ($text, $task) = @_;

=item

    # Původní volání metodou GET - neprošly delší texty

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

=cut

=item

    # Nefunkční pokus o volání metodou POST

    # Nastavení URL pro volání REST::API
    my $url = 'http://lindat.mff.cuni.cz/services/udpipe/api/process';

    # Připravení dat pro POST požadavek
    my %post_data = (
        tokenizer => 'ranges',
        tagger => 1,
        parser => 1,
        data => uri_escape_utf8($text)
    );

    if ($input_format eq 'presegmented') {
        $post_data{tokenizer} .= ';presegmented';
    }

    # Vytvoření instance LWP::UserAgent
    my $ua = LWP::UserAgent->new;

    # Vytvoření POST požadavku s daty jako JSON
    my $req = HTTP::Request->new('POST', $url);
    $req->header('Content-Type' => 'application/json');
    $req->content(encode_json(\%post_data));

=cut

    my $model;
    my $input;
    my $tagger;
    my $parser;

    if ($task eq 'segment') {
      $input = 'tokenizer=ranges';
      if ($input_format eq 'presegmented') {
        $input .= ';presegmented';
      }
      $model = '&model=czech-pdtc1.0';
      $tagger = '';
      $parser = '';
    }
    elsif ($task eq 'parse') {
      $input = 'input=conllu';
      $model = '&model=czech';
      $tagger = '&tagger';
      $parser = '&parser';
    
    }

    # Funkční volání metodou POST, i když podivně kombinuje URL-encoded s POST

    # Nastavení URL pro volání REST::API s parametry
    my $url = "http://lindat.mff.cuni.cz/services/udpipe/api/process?$input$model$tagger$parser";
    print STDERR "Call UDPipe: URL=$url\n";
    
    my $ua = LWP::UserAgent->new;

    # Define the data to be sent in the POST request
    my $data = "data=" . uri_escape_utf8($text);

    my $req = HTTP::Request->new('POST', $url);
    $req->header('Content-Type' => 'application/x-www-form-urlencoded');
    $req->content($data);


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
        print STDERR "call_udpipe: URL: $url\n";
        print STDERR "call_udpipe: Text: $text\n";
        print STDERR "call_udpipe: Chyba: " . $res->status_line . "\n";
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
    my $max_sentences = 100; # 5 was too large at first attempt, so let us hope 1 is safe enough.
    
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

=item
    
    # Stará verze metodou GET
    
    # Nastavení URL pro volání REST::API s parametry
    my $url = 'http://lindat.mff.cuni.cz/services/nametag/api/recognize?input=conllu&output=conllu-ne&data=' . uri_escape_utf8($conll);

    # Vytvoření instance LWP::UserAgent
    my $ua = LWP::UserAgent->new;

    # Vytvoření požadavku
    my $req = HTTP::Request->new('GET', $url);
    $req->header('Content-Type' => 'application/json');

=cut

    # Funkční volání metodou POST, i když podivně kombinuje URL-encoded s POST

    # Nastavení URL pro volání REST::API s parametry
    my $url = 'http://lindat.mff.cuni.cz/services/nametag/api/recognize?input=conllu&output=conllu-ne';

    my $ua = LWP::UserAgent->new;

    # Define the data to be sent in the POST request
    my $data = "data=" . uri_escape_utf8($conll);

    my $req = HTTP::Request->new('POST', $url);
    $req->header('Content-Type' => 'application/x-www-form-urlencoded');
    $req->content($data);


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
        print STDERR "call_nametag_part: URL: $url\n";
        print STDERR "call_nametag_part: Chyba: " . $res->status_line . "\n";
        return $conll; 
    }
}
