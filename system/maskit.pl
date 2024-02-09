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
use Time::HiRes qw(gettimeofday tv_interval); # to measure how long the program ran
use Sys::Hostname;

# STDIN and STDOUT in UTF-8
binmode STDIN, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my $start_time = [gettimeofday];

my $VER = '0.51 20240209'; # version of the program

my @features = ('first names',
                'surnames (male and female tied)',
                'phone numbers',
                'e-mails',
                'street names (incl. multiword)',
                'street numbers',
                'town/town part names (incl. multiword)',
                'ZIP codes',
                'company names (incl. multiword)',
                'commercial register number (IČO)',
                'tax register number (DIČ)',
                'land registration numbers (registrační čísla pozemků)',
                'birth registration numbers (rodná čísla)',
                'dates of birth/death',
                'agenda reference numbers (čísla jednací)');

my $FEATS = join(' • ', @features); 

my $DESC = "<h4>Categories handled in this MasKIT version:</h4>\n<ul>\n";

foreach my $feature (@features) {
  $DESC .= "<li>$feature\n";
}

$DESC .= <<END_DESC;
</ul>
<h4>Categories NOT yet handled:</h4>
<ul>
<li>ID card numbers (čísla občanských průkazů)
<li>driver licence numbers
<li>passport numbers
<li>account numbers
<li>data box numbers (čísla datových schránek)
<li>Údaje o spisech: spisové značky, čárové/qr kódy
</ul>
END_DESC

my $log_level = 0; # limited (0=full, 1=limited, 2=anonymous)

my $udpipe_service_url = 'http://lindat.mff.cuni.cz/services/udpipe/api';
my $nametag_service_url = 'http://lindat.mff.cuni.cz/services/nametag/api';
my $hostname = hostname;
if ($hostname eq 'maskit') { # if running at this server, use versions of udpipe and nametag that do not log texts
  $udpipe_service_url = 'http://udpipe:11001';
  $nametag_service_url = 'http://udpipe:11002';
  $VER .= ' (no text logging)';
  $log_level = 2; # anonymous
}



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
my $color_replacement_nm = 'brown'; # land registration number (katastrální číslo pozemku)
my $color_replacement_nxy = 'darkred'; # birth registration number
my $color_replacement_tabc = 'darkred'; # date of birth
my $color_replacement_tijk = 'darkred'; # date of death
my $color_replacement_nr = 'darkviolet'; # agenda reference number (číslo jednací)

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
my $randomize;
my $output_format;
my $diff;
my $add_NE;
my $output_statistics;
my $store_format;
my $store_statistics;
my $version;
my $info;
my $help;

# getting the arguements
GetOptions(
    'i|input-file=s'         => \$input_file, # the name of the input file
    'si|stdin'               => \$stdin, # should the input be read from STDIN?
    'if|input-format=s'      => \$input_format, # input format, possible values: txt, presegmented
    'rf|replacements-file=s' => \$replacements_file, # the name of the file with replacements
    'r|randomize'            => \$randomize, # if used, the replacements are selected in random order
    'of|output-format=s'     => \$output_format, # output format, possible values: txt, html, conllu
    'd|diff'                 => \$diff, # display the original expressions next to the anonymized versions
    'ne|named-entities=s'    => \$add_NE, # add named entities as marked by NameTag (1: to the anonymized versions, 2: to all recognized tokens)
    'os|output-statistics'   => \$output_statistics, # adds statistics to the output; if present, output is JSON with two items: data (in output-format) and stats (in HTML)
    'sf|store-format=s'      => \$store_format, # log the result in the given format: txt, html, conllu
    'ss|store-statistics'    => \$store_statistics, # should statistics be logged as an HTML file?
    'v|version'              => \$version, # print the version of the program and exit
    'n|info'                 => \$info, # print the info (program version and supported features) as JSON and exit
    'h|help'                 => \$help, # print a short help and exit
);


my $script_path = $0;  # Získá název spuštěného skriptu s cestou
my $script_dir = dirname($script_path);  # Získá pouze adresář ze získané cesty


if ($version) {
  print "Anonymizer version $VER.\n";
  exit 0;
}

if ($info) {
  my $json_data = {
       version  => $VER,
       features => $FEATS,
     };
  # Encode the Perl data structure into a JSON string
  my $json_string = encode_json($json_data);
  # Print the JSON string to STDOUT
  print $json_string;
  exit 0;
}

if ($help) {
  print "Anonymizer version $VER.\n";
  my $text = <<'END_TEXT';
Usage: maskit.pl [options]
options:  -i|--input-file [input text file name]
         -si|--stdin (input text provided via stdin)
         -if|--input-format [input format: txt (default) or presegmented]
         -rf|--replacements-file [replacements file name]
          -r|--randomize (if used, the replacements are selected in random order)
         -of|--output-format [output format: txt (default), html, conllu]
          -d|--diff (display the original expressions next to the anonymized versions)
         -ne|--named-entities [scope: 1 - add NameTag marks to the anonymized versions, 2 - to all recognized tokens]
         -os|--output-statistics (add MasKIT statistics to output; if present, output is JSON with two items: data (in output-format) and stats (in HTML))
         -sf|--store-format [format: log the output in the given format: txt, html, conllu]
         -ss|--store-statistics (log statistics to an HTML file)
          -v|--version (prints the version of the program and ends)
          -n|--info (prints the program version and supported features as JSON and ends)
          -h|--help (prints a short help and ends)
END_TEXT
  print $text;
  exit 0;
}

###################################################################################
# Summarize the program arguments to the log (except for --version and --help)
###################################################################################

mylog(2, "\n####################################################################\n");
mylog(2, "MasKIT $VER\n");

mylog(0, "Arguments:\n");
 

if ($stdin) {
  mylog(0, " - input: STDIN\n");
}
elsif ($input_file) {
  mylog(0, " - input: file $input_file\n");
}

if (!defined $input_format) {
  mylog(0, " - input format: not specified, set to default $INPUT_FORMAT_DEFAULT\n");
  $input_format = $INPUT_FORMAT_DEFAULT;
}
elsif ($input_format !~ /^(txt|presegmented)$/) {
  mylog(0, " - input format: unknown ($input_format), set to default $INPUT_FORMAT_DEFAULT\n");
  $input_format = $INPUT_FORMAT_DEFAULT;
}
else {
  mylog(0, " - input format: $input_format\n");
}

if (!defined $replacements_file) {
  mylog(0, " - replacements file: not specified, set to default $REPLACEMENTS_FILE_DEFAULT\n");
  $replacements_file = "$script_dir/$REPLACEMENTS_FILE_DEFAULT";
}
else {
  mylog(0, " - replacements file: $replacements_file\n");
}

if ($randomize) {
  mylog(0, " - replacements will be selected in random order\n");
}
else {
  mylog(0, " - replacements will be selected in order as present in the replacements file\n");
}

$output_format = lc($output_format) if $output_format;
if (!defined $output_format) {
  mylog(0, " - output format: not specified, set to default $OUTPUT_FORMAT_DEFAULT\n");
  $output_format = $OUTPUT_FORMAT_DEFAULT;
}
elsif ($output_format !~ /^(txt|html|conllu)$/) {
  mylog(0, " - output format: unknown ($output_format), set to default $OUTPUT_FORMAT_DEFAULT\n");
  $output_format = $OUTPUT_FORMAT_DEFAULT;
}
else {
  mylog(0, " - output format: $output_format\n");
}

if ($diff) {
  mylog(0, " - display the original expressions next to the anonymized versions\n");
}

if ($add_NE) {
  if ($add_NE == 1) {
    mylog(0, " - add named entities as marked by NameTag to the anonymized versions\n");
  }
  elsif ($add_NE == 2) {
    mylog(0, " - add named entities as marked by NameTag to all recognized tokens\n");  
  }
  else {
    mylog(0, " - unknown value of -ne/--named-entities parameter ($add_NE); no NameTag marks will be printed\n");    
  }
}

if ($output_statistics) {
  mylog(0, " - add MasKIT statistics to the output; output will be JSON with two items: data (in $output_format) and stats (in HTML)\n");
}

$store_format = lc($store_format) if $store_format;
if ($store_format) {
  if ($store_format =~ /^(txt|html|conllu)$/) {
    mylog(0, " - log the output to a file in $store_format\n");
  }
  else {
    mylog(0, " - unknown format for logging the output ($store_format); the output will not be logged\n");
    $store_format = undef;
  }
}

if ($store_statistics) {
  mylog(0, " - log MasKIT statistics in an HTML file\n");
}

mylog(0, "\n");

###################################################################################
# Let us first read the file with replacements
###################################################################################

my %class_constraint2replacements; # NameTag class + constraint => replacements separated by |; the class is separated by '_' from the constraint
my %class_constraint2group; # grouping e.g. first names across cases and surnames across cases and genders together
my %class2constraints; # which constraints does the class require (if any); the individual constraints are separated by '_'; an empty constraint is represented by 'NoConstraint'

mylog(2, "Reading replacements from $replacements_file\n");

open (REPLACEMENTS, '<:encoding(utf8)', $replacements_file)
  or die "Could not open file '$replacements_file' for reading: $!";

my %group2reordering; # reordering of replacements for a given group
# values of the hash are arrays that contain new indexes for each array index; the length of the array is the same as number of replacements in one replacement line in the given group

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
    if ($randomize) { # randomly mix the replacements (but in the same way for all replacement lines in the same group)
      #mylog(0, "Before randomization: $group\t$replacements\n");
      $replacements = reorder_replacements($replacements, $group);
      #mylog(0, "After randomization:  $group\t$replacements\n");
    }
    $class_constraint2replacements{$class . '_' . $constraint} = $replacements;
    $class_constraint2group{$class . '_' . $constraint} = $group;
    mylog(0, "Class $class with constraint $constraint, group $group and replacements $replacements\n");
    $replacements_count++;
    if ($class2constraints{$class}) { # if there already was a constraint for this class
      mylog(0, "Note: multiple constraints for class $class.\n");
      $class2constraints{$class} .= "_";
    }
    $class2constraints{$class} .= $constraint;
  }
  else {
    mylog(2, "Unknown format of a line in file $replacements_file:\n$line\n");
  }
}
mylog(2, "$replacements_count replacement rules have been read from file $replacements_file:\n");

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
  mylog(2, "No input to process! Exiting!\n");
  exit -1;
}

mylog(2, "input file: $input_file\n");

# mylog(0, $input_content);


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
# Now let us add info about named entities¨ using NameTag REST API
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
    #mylog(0, "Line: $line\n");
    if ($line =~ /^#/ && !$root) {
        $root = Tree::Simple->new({}, Tree::Simple->ROOT);
        #mylog(0, "Beginning of a new sentence!\n");
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
        #mylog(0, "Reading sentence '$1'\n");
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
        #mylog(0, "End of sentence id='" . attr($root, 'id') . "'.\n\n");
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
    #mylog(0, "End of sentence id='" . attr($root, 'id') . "'.\n\n");
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

my $processing_time;
# print_log_header();

# variables and hashes for statistics
my $sentences_count = scalar(@trees);
my $tokens_count = 0;

foreach $root (@trees) {
  mylog(1, "\n====================================================================\n");
  mylog(1, "Sentence id=" . attr($root, 'id') . ": " . attr($root, 'text') . "\n");
  # print_children($root, "\t");
  
  my @nodes = descendants($root);
  $tokens_count += scalar(@nodes) - 1; # without the root

  foreach my $node (@nodes) {
  
    my $lemma = attr($node, 'lemma') // '';
    my $tag = attr($node, 'xpostag') // '';
    my $form = attr($node, 'form') // '';
    my $feats = attr($node, 'feats') // '';
    my $classes = get_NameTag_marks($node) // '';

    # Check if the node is a part of a multiword expression (e.g., a multiword street name) hidden by its predecessor (i.e., by the root of the multiword expr.)
    my $hidden = attr($node, 'hidden') // '';
    if ($hidden) {
      mylog(0, "Skipping node '$form' hidden by '$hidden'\n");
      next;
    }

    next if !$classes; # no NameTag class found here

    mylog(0, "\nProcessing form '$form' (lemma '$lemma') with NameTag classes '$classes' and feats '$feats'\n");

    foreach my $class (split('~', $classes)) {
    
      my $constraints = $class2constraints{$class};
      if (!$constraints) {
        mylog(0, "No constraints for NE class '$class', skipping.\n");
        next;
      }
      mylog(0, "Found constraints '$constraints' for NE class '$class'\n");

      foreach my $constraint (split(/_/, $constraints)) { # split the constraints by separator '_' and work with one constraint at a time

        my $matches = check_constraint($node, $constraint); # check if the constraint is met (e.g., Gender=Fem); empty constraint is represented by 'NoConstraint'
        if (!$matches) {
          mylog(0, " - the constraint '$constraint' for form '$form' is not met.\n");
          next;
        }
        mylog(0, " - the constraint '$constraint' for form '$form' matches.\n");
        my $replacement = get_replacement($node, $class, $constraint);
        mylog(0, "    - replacement in class $class: '$form' -> '$replacement'\n");
        set_attr($node, 'replacement', $replacement);
        
        # Check if this node is a root of a multiword expression such as street name; in that case hide some descendants
        check_and_hide_multiword($node, $class);
        
        last;
      }
    }
  }  
}

# print_log_tail();

# Measure time spent so far
my $end_time = [gettimeofday];
$processing_time = tv_interval($start_time, $end_time);

# calculate and format statistics if needed
my $stats;
if ($store_statistics or $output_statistics) { # we need to calculate statistics
  $stats = get_stats();
}

# print the input text with marked sources in the selected output format to STDOUT
my $output = get_output($output_format);

if (!$output_statistics) { # statistics should not be a part of output
  print $output;
}
else { # statistics should be a part of output, i.e. output will be JSON with two items: data (in output-format) and stats (in html)
  my $json_data = {
       data  => $output,
       stats => $stats,
     };
  # Encode the Perl data structure into a JSON string
  my $json_string = encode_json($json_data);
  # Print the JSON string to STDOUT
  print $json_string;  
}

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

=item log

A function to print log (debug) info based on $log_level (0=full, 1=limited, 2=anonymous).
The message only gets printed (to STDERR) if given $level is greater than or equal to global $log_level.

=cut

sub mylog {
  my ($level, $msg) = @_;
  if ($level >= $log_level) {
    print STDERR "maskit: $msg";
  }
}


=item check_constraint

Check if the constraint is met at the node.

The constraint is a sequence of morphological properties from UD attribute feats, e.g.:
Gender=Masc|Number=Sing
A meta property length may be a part of the constraint, e.g. length=3 or length>9

Returns 0 if the constraint (all parts) is not met.
Otherwise returns 1.

=cut


sub check_constraint {
  my ($node, $constraint) = @_;

  if ($constraint eq 'NoConstraint') { # no constraint, i.e. trivially matched
    mylog(0, " - no constraint, i.e. trivially matched\n");
    return 1;
  }

  my $feats = attr($node, 'feats') // '';
  my $form = attr($node, 'form') // '';
  mylog(0, "check_constraint: checking constraint '$constraint' against form '$form' and feats '$feats'\n");

  my @a_constraints = split('\|', $constraint); # get the individul features
  foreach my $feature (@a_constraints) {
    mylog(0, " - checking if '$feature' matches\n");
    if ($feature =~ /^length([<=>])(\d+)$/) {
      my ($operator, $value) = ($1, $2);
      my $length = length($form);
      mylog(0, "     - checking length comparison: '$length $operator $value'\n");      
      if ($operator eq '=') {
        return $length == $value;
      }
      if ($operator eq '>') {
        return $length > $value;
      }
      if ($operator eq '<') {
        return $length < $value;
      }
    }
    if ($feats !~ /\b$feature\b/) { # $feature not in $feats
      mylog(0, "   - constraint $feature not matching; returning 0\n");
      return 0;
    }
    mylog(0, "   - constraint $feature not matches\n");
  }
  mylog(0, " - OK, all features matched, the constraint matches.\n");
  return 1;
}

=item get_NameTag_marks

Get a list of NameTag marks assigned to the given node; the return value is a string of the marks divided by '~'.
Fake marks are assigned for cases not recognized by NameTag:

ax - the first part (three digits) of a ZIP code
ay - the second part (two digits) of a ZIP code

nk - IČO
nl - DIČ

nm - land register number

nx - the first part (six digits) of a birth registration number
ny - the second part (four or three digits) of a birth registration number

ta - day of birth
tb - month of birth
tc - year of birth

ti - day of death
tj - month of death
tk - year of death

nr - agenda reference number (číslo jednací)

=cut

sub get_NameTag_marks {
  my $node = shift;
  my @values = get_NE_values($node);
  my $marks = join '~', @values;
  # mylog(0, "get_NameTag_marks: $ne -> $marks\n");

  my $lemma = attr($node, 'lemma') // '';
  
  my $parent = $node->getParent;
  my $parent_lemma = '';
  if ($parent) {
    $parent_lemma = attr($parent, 'lemma') // '';
  }
  
  # Birth registration number
  if (is_birth_number_part1($node)) {
    return 'nx'; # fake mark for firt part of birth registration number
  }
  if (is_birth_number_part2($node)) {
    return 'ny'; # fake mark for second part of birth registration number
  }

  # hide 'hlavní' if dependent on 'město' and do not assign any tag to this 'město' 
  if ($lemma eq 'město') {
    my @sons_hlavni = grep {attr($_, 'lemma') eq 'hlavní'} $node->getAllChildren;
    if (@sons_hlavni) {
      my $hlavni = $sons_hlavni[0];
      set_attr($hlavni, 'hidden', attr($node, 'ord')); # hiding 'hlavní' in 'hlavní město'
      return undef; # in this case 'město' should not be a part of the town name (unlike e.g. Nové město nad Metují)
    }
  }

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

  # unrecognized second part of a street number (after '/')
  if ($lemma =~ /^[1-9][0-9]*$/ and $marks !~ /\bah\b/) {
    my $parent_ne = join('~', get_NE_values($parent));
    if ($parent_ne =~ /\bah\b/) { # parent was recognized as a street number
      my @children_slash = grep {attr($_, 'form') eq '/'} $node->getAllChildren;
      if (@children_slash) { # there is a slash among children
        return 'ah'; # so this is also a street number
      }
    }
  }

  # street names that are wrongly considered also surnames
  if ($marks =~ /\bgs\b/ and $marks =~ /\bps\b/) {
    # check if there are street numbers among children
    my @children = $node->getAllChildren;
    foreach my $child (@children) {
      my $child_ne = join('~', get_NE_values($child));
      if ($child_ne =~ /\bah\b/) { # a street number among children
        return 'gs'; # mark this only as a street name, not also as a surname
      }
    }
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
    #my $parent_ne = get_misc_value($parent, 'NE') // '';
    #my @parent_values = $parent_ne =~ /([A-Za-z][a-z_]?)_[0-9]+/g;
    #my $parent_marks = join '~', @parent_values;
    my $parent_marks = join('~', get_NE_values($parent));
    if ($parent_lemma =~ /^[1-9][0-9][0-9]$/ and $parent_marks=~ /\ba[zt]\b/) { # the parent looks like the first part of a ZIP code
      return 'ay'; # a fake mark for the second part of a ZIP code
    }
  }

  # date of birth/death
  if (is_day_of_birth($node)) {
    return 'ta';
  }
  if (is_month_of_birth($node)) {
    return 'tb';
  }
  if (is_year_of_birth($node)) {
    return 'tc';
  }
  if (is_day_of_death($node)) {
    return 'ti';
  }
  if (is_month_of_death($node)) {
    return 'tj';
  }
  if (is_year_of_death($node)) {
    return 'tk';
  }

  # IČO
  if (is_ICO($node)) {
    return 'nk'; # fake mark for IČO
  }

  # DIČ
  if (is_DIC($node)) {
    return 'nl'; # fake mark for DIČ
  }

  # agenda reference number (číslo jednací)
  if (is_agenda_ref_number($node)) {
    return 'nr'; # fake mark for agenda reference number
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
        return 'gq'; # urban part
      }
      else {
        $marks .= '~gq';
      }
    }
  }

  # Land register number
  if (is_land_register_number($node)) {
    if (!$marks) { # nothing was recognized by NameTag
      return 'nm'; # fake mark for land register number
    }
    else {
      $marks .= '~nm'; # fake mark for land register number
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

Returns 1 if it is a day in the expression of someone's date of birth

=cut

sub is_day_of_birth {
  my ($node) = @_;
  my $form = attr($node, 'form') // '';;
  if ($form =~ /^(1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31)$/) {
    my $parent = $node->getParent;
    return 0 if !$parent;
    my $parent_form = attr($parent, 'form');
    if ($parent_form =~ /^(1|2|3|4|5|6|7|8|9|10|11|12)$/) {
      my @year_brothers = grep {attr($_, 'form') =~ /^[12][09][0-9][0-9]$/} $parent->getAllChildren;
      if (scalar(@year_brothers) == 1) {
        my $grandparent = $parent->getParent;
        return 0 if !$grandparent;
        my $grandparent_form = attr($grandparent, 'form') // '';
        my $grandparent_lemma = attr($grandparent, 'lemma') // '';
        if ($grandparent_lemma =~ /^(narozený)$/ or $grandparent_form =~ /^(nar|n)$/) {
          return 1;
        }
      }
    }
  }
  return 0;
}

=item

Returns 1 if it is a month in the expression of someone's date of birth

=cut

sub is_month_of_birth {
  my ($node) = @_;
  my $form = attr($node, 'form') // '';;
  if ($form =~ /^(1|2|3|4|5|6|7|8|9|10|11|12)$/) {
    my $parent = $node->getParent;
    return 0 if !$parent;
    my $parent_form = attr($parent, 'form');
    my $parent_lemma = attr($parent, 'lemma') // '';
    if ($parent_lemma =~ /^(narozený)$/ or $parent_form =~ /^(nar|n)$/) {
      my @year_sons = grep {attr($_, 'form') =~ /^[12][09][0-9][0-9]$/} $node->getAllChildren;
      my @day_sons = grep {attr($_, 'form') =~ /^(1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31)$/} $node->getAllChildren;
      if (scalar(@year_sons) == 1 and scalar(@day_sons)) {
        return 1;
      }
    }
  }
  return 0;
}

=item

Returns 1 if it is a year in the expression of someone's date of birth

=cut

sub is_year_of_birth {
  my ($node) = @_;
  my $form = attr($node, 'form') // '';;
  if ($form =~ /^[12][09][0-9][0-9]$/) {
    my $parent = $node->getParent;
    return 0 if !$parent;
    my $parent_form = attr($parent, 'form');
    if ($parent_form =~ /^(1|2|3|4|5|6|7|8|9|10|11|12)$/) {
      my @day_brothers = grep {attr($_, 'form') =~ /^(1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31)$/} $parent->getAllChildren;
      if (scalar(@day_brothers) == 1) {
        my $grandparent = $parent->getParent;
        return 0 if !$grandparent;
        my $grandparent_form = attr($grandparent, 'form') // '';
        my $grandparent_lemma = attr($grandparent, 'lemma') // '';
        if ($grandparent_lemma =~ /^(narozený)$/ or $grandparent_form =~ /^(nar|n)$/) {
          return 1;
        }
      }
    }
  }
  return 0;
}

=item

Returns 1 if it is a day in the expression of someone's date of death

=cut

sub is_day_of_death {
  my ($node) = @_;
  my $form = attr($node, 'form') // '';
  if ($form =~ /^(1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31)$/) {
    my $parent = $node->getParent;
    return 0 if !$parent;
    my $parent_form = attr($parent, 'form');
    if ($parent_form =~ /^(1|2|3|4|5|6|7|8|9|10|11|12)$/) {
      my @year_brothers = grep {attr($_, 'form') =~ /^[12][09][0-9][0-9]$/} $parent->getAllChildren;
      if (scalar(@year_brothers) == 1) {
        my $grandparent = $parent->getParent;
        return 0 if !$grandparent;
        my $grandparent_form = attr($grandparent, 'form') // '';
        my $grandparent_lemma = attr($grandparent, 'lemma') // '';
        if ($grandparent_lemma =~ /^(zemřelý)$/ or $grandparent_form =~ /^(zem|z)$/) {
          return 1;
        }
      }
    }
  }
  return 0;
}

=item

Returns 1 if it is a month in the expression of someone's date of death

=cut

sub is_month_of_death {
  my ($node) = @_;
  my $form = attr($node, 'form') // '';
  if ($form =~ /^(1|2|3|4|5|6|7|8|9|10|11|12)$/) {
    my $parent = $node->getParent;
    return 0 if !$parent;
    my $parent_form = attr($parent, 'form');
    my $parent_lemma = attr($parent, 'lemma') // '';
    if ($parent_lemma =~ /^(zemřelý)$/ or $parent_form =~ /^(zem|z)$/) {
      my @year_sons = grep {attr($_, 'form') =~ /^[12][09][0-9][0-9]$/} $node->getAllChildren;
      my @day_sons = grep {attr($_, 'form') =~ /^(1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31)$/} $node->getAllChildren;
      if (scalar(@year_sons) == 1 and scalar(@day_sons)) {
        return 1;
      }
    }
  }
  return 0;
}

=item

Returns 1 if it is a year in the expression of someone's date of death

=cut

sub is_year_of_death {
  my ($node) = @_;
  my $form = attr($node, 'form') // '';
  if ($form =~ /^[12][09][0-9][0-9]$/) {
    my $parent = $node->getParent;
    return 0 if !$parent;
    my $parent_form = attr($parent, 'form');
    if ($parent_form =~ /^(1|2|3|4|5|6|7|8|9|10|11|12)$/) {
      my @day_brothers = grep {attr($_, 'form') =~ /^(1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31)$/} $parent->getAllChildren;
      if (scalar(@day_brothers) == 1) {
        my $grandparent = $parent->getParent;
        return 0 if !$grandparent;
        my $grandparent_form = attr($grandparent, 'form') // '';
        my $grandparent_lemma = attr($grandparent, 'lemma') // '';
        if ($grandparent_lemma =~ /^(zemřelý)$/ or $grandparent_form =~ /^(zem|z)$/) {
          return 1;
        }
      }
    }
  }
  return 0;
}


=item

Returns 1 if the given node appears to be a land register number (katastrální číslo pozemku). Otherwise returns 0.
Technically, it returns 1 if:
- it is a number
- and among its predecessors on the part of the path to the root with deprels nmod or nummod (and the final parent of any deprel) is at least one of:
   - lemma 'pozemek'
   - or lemma 'číslo' and its parent has form 'p' (p. č.)

=cut

sub is_land_register_number {
  my $node = shift;
  my $form = attr($node, 'form') // '';
  my $deprel = attr($node, 'deprel') // '';
  if ($form =~ /^\d+$/) { # a number
    my $parent = $node->getParent;
    return 0 if !$parent;
    while ($deprel =~ /^(conj|nmod|nummod)$/) {
      my $parent_deprel = attr($parent, 'deprel') // '';
      my $parent_form = attr($parent, 'form') // '';
      my $parent_lemma = attr($parent, 'lemma') // '';
      if ($parent_lemma =~ /^pozemek$/) {
        return 1;
      }
      if ($parent_lemma =~ /^číslo$/) {
        my $grandparent = $parent->getParent;
        if ($grandparent) {
          my $grandparent_form = attr($grandparent, 'form') // '';
          if ($grandparent_form eq 'p') {
            return 1;
          }
        }
      }
      $deprel = $parent_deprel;
      $parent = $parent->getParent;
    }
  }
  return 0;
}


=item

Returns 1 if the given node appears to be an agenda reference number (číslo jednací). Otherwise returns 0.
Technically, it returns 1 if:
- it is a number
- and:
  - its parent is lemma číslo/č and among the parent's sons there is lemma jednací/j
  - or its parent is lemma j and among its sons there is lemma číslo/č

=cut

sub is_agenda_ref_number {
  my $node = shift;
  my $form = attr($node, 'form') // '';
  my $deprel = attr($node, 'deprel') // '';
  if ($form =~ /^\d+$/) { # a number
    my $parent = $node->getParent;
    return 0 if !$parent;
    my $parent_form = lc(attr($parent, 'form')) // '';
    my $parent_lemma = attr($parent, 'lemma') // '';
    if ($parent_lemma eq 'číslo' or $parent_form eq 'č') {
      my @good_sons = grep {attr($_, 'lemma') eq 'jednací' or lc(attr($_, 'form')) eq 'j'} $parent->getAllChildren;
      if (@good_sons) {
        return 1;
      }
    }
    if ($parent_lemma eq 'jednací' or $parent_form eq 'j') {
      my @good_sons = grep {attr($_, 'lemma') eq 'číslo' or lc(attr($_, 'form')) eq 'č'} $parent->getAllChildren;
      if (@good_sons) {
        return 1;
      }
    }
  }
  return 0;
}


=item

Returns 1 if the given node appears to be the first part of a birth registration number. Otherwise returns 0.
Technically, it returns 1 if:
- the node is a 6-digit number and:
   - the first two-digit number is less than 54 and its only son is a 3 digit number
   - or the first two-digit number is greater than 53 and its only son is a 4 digit number and together the 10-digit number is divisible by 11
   - or the first two-digit number is greater than 53 and its only son is a 4 digit number, the last digit is 0 and the 9-digit number (without the last digit) divided by 11 gives 10
- and the grandson is '/'

=cut

sub is_birth_number_part1 {
  my $node = shift;
  my $lemma = attr($node, 'lemma') // '';

  if ($lemma =~ /^([0-9][0-9])[0-9][0-9][0-9][0-9]$/) { # might be the first part of a birth registration number
    #mylog(0, "is_birth_number_part1: six-digit number\n");
    my $year = $1;
    my @sons = $node->getAllChildren;
    my @RC2_children = grep {attr($_, 'lemma') =~ /^[0-9][0-9][0-9][0-9]?$/} @sons;
    if (scalar(@sons) == 1 and scalar(@RC2_children) == 1) { # it has the only one and correct son
      #mylog(0, "is_birth_number_part1: single three- or four-digit number\n");
      my $son = $RC2_children[0];
      my @grandsons = $son->getAllChildren;
      if (scalar(@grandsons) == 1 and attr($grandsons[0], 'lemma') eq '/') { # the only grandson is '/'
        my $RC2 = attr($son, 'lemma');
        #mylog(0, "is_birth_number_part1: grandson '/', year: '$year', son: '$RC2', length: " . length($RC2) . "\n");
        if ($year < 54 and length($RC2) == 3) {
          #mylog(0, "is_birth_number_part1: year<54 and three-digit number\n");
          return 1; # a birth registration number up to the year 1953
        }
        if ($year > 53 and length($RC2) == 4) { # might be a birth reg. number since 1954
          #mylog(0, "is_birth_number_part1: year>53 and four-digit number\n");
          my $whole = $lemma . $RC2;
          my $remainder = $whole % 11;
          if ($remainder == 0) { # divisible by 11
            return 1;
          }
          if (substr($whole, -1) eq '0') { # last digit is 0
            my $whole_without_last = substr($whole, 0, -1);
            $remainder = $whole_without_last % 11;
            if ($remainder == 10) { # the first 9-digit part after division by 11 gives 10
              return 1;
            }
          }
        }
      }
    }
  }
  return 0;
}

sub is_birth_number_part2 {
  my $node = shift;
  my $parent = $node->getParent;
  if (is_birth_number_part1($parent)) {
    return 1;
  }
  return 0;
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
either:
- the form starts with a capital letter
- and it is an adjective or a noun (incl. a proper noun)
- and NameTag did not assign any g-mark to it (because also town may depend on 'ulice', e.g. in "ulice Kralická v Prostějově"
- and the lemma of the parent is 'ulice'
or:
- the form starts with a capital letter
- and it is an adjective or a noun (incl. a proper noun)
- and NameTag did not assign any g-mark to it (because also town may depend on 'ulice', e.g. in "ulice Kralická v Prostějově"
- and NameTag assigned 'ps' to it (surname)
- and there is a number among its sons


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
      my @number_sons = grep {attr($_, 'form') =~ /^\d+$/} $node->getAllChildren;
      if (@number_sons) {
        my @nametag_ps_marks = grep {/ps/} get_NE_values($node);
        if (@nametag_ps_marks) {
          return 1;
        }
      }
    }
  }
  return 0;
}


=item check_and_hide_multiword

Checks if the node is a root of a multiword expression such as a street name (Nábřeží Kapitána Jaroše); in that case hides some of the descendants.
The nodes are hidden by setting attribute 'hidden' to id (i.e., ord) of the root of the multiword phrase.
If the last hidden node has SpaceAfter=No, it is set at the "root" node

=cut

sub check_and_hide_multiword {
  my ($node, $class) = @_;
  my @hidden_nodes = check_and_hide_multiword_recursive(attr($node, 'ord'), $node, $class);
  if (@hidden_nodes) {
    my @sorted = sort {attr($a, 'ord') <=> attr($b, 'ord')} @hidden_nodes;
    my $last = $sorted[-1]; # the last of the hidden nodes
    my $SpaceAfter = get_misc_value($last, 'SpaceAfter') // '';
    my $SpaceAfterOrig = get_misc_value($node, 'SpaceAfter') // '';
    if ($SpaceAfter eq 'No') { # we need to set this property for $node
      set_property($node, 'misc', 'SpaceAfter', 'No');
      if ($SpaceAfterOrig ne 'No') { # but we need to leave info that originally there was space here (for displaying orig text)
        set_property($node, 'misc', 'SpaceAfterOrig', 'Yes');
      }
    }
    my $SpacesAfter = get_misc_value($last, 'SpacesAfter') // '';
    if ($SpacesAfter) { # we need to set this property for $node
      set_property($node, 'misc', 'SpacesAfter', $SpacesAfter);
    }
  }
}
    
sub check_and_hide_multiword_recursive {
  my ($id, $node, $class) = @_;
  my @name_parts = ();
  my @recursive_name_parts = ();
  if ($class eq 'gs') { # a street name
    @name_parts = grep {grep {/gs/} get_NameTag_marks($_) and attr($_, 'deprel') =~ /(amod|nmod|flat|case)/}
                  grep {attr($_, 'form') ne 'PSČ'}
                  $node->getAllChildren;
    foreach my $street_name_part (@name_parts) {
      set_attr($street_name_part, 'hidden', $id);
      mylog(0, "Hiding street name part " . attr($street_name_part, 'form') . "\n");
      @recursive_name_parts = check_and_hide_multiword_recursive($id, $street_name_part, $class);
    }
  }
  elsif ($class eq 'gu' or $class eq 'gq') { # a town / town part
    @name_parts = grep {grep {/(gu|gq)/} get_NameTag_marks($_) and attr($_, 'deprel') =~ /(amod|nmod|flat|case|nummod)/}
                  grep {attr($_, 'form') ne 'PSČ'}
                  $node->getAllChildren;
    foreach my $town_name_part (@name_parts) {
      set_attr($town_name_part, 'hidden', $id);
      mylog(0, "Hiding town name part " . attr($town_name_part, 'form') . "\n");
      my @puncts = grep {attr($_, 'deprel') eq 'punct'} $town_name_part->getAllChildren; # punctuation such as in "Praha 7 - Holešovice"
      foreach my $punct (@puncts) {
        set_attr($punct, 'hidden', $id);
        mylog(0, "Hiding punctuation in town name '" . attr($punct, 'form') . "'\n");
      }
      push(@name_parts, @puncts);
      @recursive_name_parts = check_and_hide_multiword_recursive($id, $town_name_part, $class);
    }
  }
  elsif ($class eq 'if') { # companies, concerns...
    @name_parts = grep {grep {/(if)/} get_NE_values($_) and attr($_, 'deprel') =~ /(amod|nmod|flat|case|nummod)/}
                  grep {attr($_, 'form') ne 'PSČ'}
                  $node->getAllChildren;
    foreach my $company_name_part (@name_parts) {
      set_attr($company_name_part, 'hidden', $id);
      mylog(0, "Hiding company name part " . attr($company_name_part, 'form') . "\n");
      my @puncts = grep {attr($_, 'deprel') eq 'punct'} $company_name_part->getAllChildren; # punctuation
      foreach my $punct (@puncts) {
        set_attr($punct, 'hidden', $id);
        mylog(0, "Hiding punctuation in company name '" . attr($punct, 'form') . "'\n");
      }
      push(@name_parts, @puncts);
      @recursive_name_parts = check_and_hide_multiword_recursive($id, $company_name_part, $class);
    }
  }
  elsif ($class eq 'nr') { # a fake mark for agenda reference number (číslo jednací)
    @name_parts = grep {attr($_, 'upostag') eq 'NUM' and attr($_, 'deprel') eq 'compound'}
                  $node->getAllChildren;
    foreach my $name_part (@name_parts) {
      set_attr($name_part, 'hidden', $id);
      mylog(0, "Hiding agenda reference number part " . attr($name_part, 'form') . "\n");
      my @puncts = grep {attr($_, 'deprel') eq 'punct'} $name_part->getAllChildren; # punctuation
      foreach my $punct (@puncts) {
        set_attr($punct, 'hidden', $id);
        mylog(0, "Hiding punctuation in agenda reference number '" . attr($punct, 'form') . "'\n");
      }
      push(@name_parts, @puncts);
      @recursive_name_parts = check_and_hide_multiword_recursive($id, $name_part, $class);
    }
  }
  
  push(@name_parts, @recursive_name_parts);
  return @name_parts;
}

=item set_property

In the given attribute at the given node (e.g., 'misc'), it sets the value of the given property.

=cut

sub set_property {
  my ($node, $attr, $property, $value) = @_;
  # mylog(0, "set_property: '$attr', '$property', '$value'\n");
  my $orig_value = attr($node, $attr) // '';
  # mylog(0, "set_property: orig_value: '$orig_value'\n");
  my @values = grep {$_ !~ /^$property\b/} grep {$_ ne ''} grep {defined} split('\|', $orig_value);
  push(@values, "$property=$value");
  my @sorted = sort @values;
  my $new_value = join('|', @sorted);
  set_attr($node, $attr, $new_value);
}


=item

# Funkce pro přeházení prvků v $replacements podle uloženého pořadí pro danou skupinu
my %group2reordering; # reordering of replacements for a given group
# values of the hash are arrays that contain new indexes for each array index; the length of the array is the same as number of replacements in one replacement line in the given group

=cut
sub reorder_replacements {
    my ($replacements, $group) = @_;

    # Pokud pro danou skupinu ještě nejsou uložené přeházené indexy, vytvoř je
    unless (exists $group2reordering{$group}) {
        my @indices = shuffle_indices(split(/\|/, $replacements));
        $group2reordering{$group} = \@indices;
    }

    # Přeházení prvků podle uložených indexů
    my @shuffled = map { (split(/\|/, $replacements))[$_] } @{$group2reordering{$group}};

    # Vrácení přeházených prvků jako řetězec oddělený svislítky
    return join('|', @shuffled);
}

# Funkce pro náhodné přeházení indexů v poli
sub shuffle_indices {
    my @indices = 0..$#_;
    for my $i (reverse 1..$#_) {
        my $j = int rand ($i+1);
        @indices[$i, $j] = @indices[$j, $i];
    }
    return @indices;
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
    mylog(0, "No replacements for NE class '$class' and constraint '$constraint', skipping.\n");
    next;
  }
  mylog(0, "  - found replacements '$replacements' for class '$class' and constraint '$constraint'\n");
  my @a_replacements = split('\|', $replacements);
  my $group = $class_constraint2group{$class_constraint};
  
  my $replacement;
  # check if this stem in this group has already been replaced
  my $replacement_index = $group_stem2index{$group . '_' . $stem};
  if (defined($replacement_index)) {
    mylog(0, "get_replacement: Found a previously assigned replacement index for group $group and stem $stem: $replacement_index\n");
    my $number_of_replacements = scalar(@a_replacements);
    if ($replacement_index >= $number_of_replacements) { # maximum index exceeded
      $replacement = '[' . $class . '_#' . $replacement_index . ']';
      mylog(0, "    - maximum replacement index $number_of_replacements exceeded by requested index $replacement_index!\n");
    }
    else {
      $replacement = $a_replacements[$replacement_index];
    }
  }
  my $new = 0;
  while (!defined($replacement_index)) { # this stem within this group has not yet been seen, so use a new index
    mylog(0, "get_replacement: Unseen group $group and stem $stem, assigning a new replacement index\n");
    $replacement_index = $group2next_index{$group} // 0;
    $group2next_index{$group}++;
    $new = 1;
    my $number_of_replacements = scalar(@a_replacements);
    if ($replacement_index >= $number_of_replacements) { # maximum index exceeded
      $replacement = '[' . $class . '_#' . $replacement_index . ']';
      mylog(0, "    - maximum replacement index $number_of_replacements exceeded by requested index $replacement_index!\n");
    }
    else {
      $replacement = $a_replacements[$replacement_index];
      if (lc($replacement) eq lc($form)) { # the replacement is accidentally equal to the original form (e.g., Praze vs. Praze); let us skip this replacement index
        mylog(0, "    - the replacement is equal to the original form ($form); let us skip this replacement index ($replacement_index)\n");
        $replacement_index = undef; # run the while cycle one more time to use the next replacement index
      }
    }
  }
  if ($new) { # let us store the index for this stem with this group
    mylog(0, "get_replacement: Storing a newly assigned replacement index ($replacement_index) for group $group and stem $stem\n");
    $group_stem2index{$group . '_' . $stem} = $replacement_index;
  }
  if ($form =~ /^\p{Lu}+$/) { # the original form is capitalized
    $replacement = uc($replacement); # capitalize also the replacement
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
  # mylog(0, "get_misc_value: token='" . attr($node, 'form') . "', misc=$misc\n");
  if ($misc =~ /$property=([^|]+)/) {
    my $value = $1;
    # mylog(0, "get_misc_value: $property=$value\n");
    return $value;
  }
  return undef;
}  

=item

sub get_misc_value {
    my ($node, $jmeno_featury) = @_;
    my $text = attr($node, 'misc') // '';
    
    my %featury;
    
    # Rozdělení textu na featury
    my @featury_sekvence = split /\|/, $text;
    
    # Parsování každé featury a uložení do hash
    foreach my $featura (@featury_sekvence) {
        if ($featura =~ /^(\w+)=(.+)$/) {
            my ($jmeno, $hodnota) = ($1, $2);
            $featury{$jmeno} = $hodnota;
        }
    }
    
    # Vrácení hodnoty featury, pokud existuje
    return $featury{$jmeno_featury};
}

=cut

=item get_feat_value

Returns a value of the given property from the feats attribute. Or undef.

=cut

sub get_feat_value {
  my ($node, $property) = @_;
  my $feats = attr($node, 'feats') // '';
  # mylog(0, "get_feat_value: feats=$feats\n");
  if ($feats =~ /$property=([^|]+)/) {
    my $value = $1;
    # mylog(0, "get_feat_value: $property=$value\n");
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
        .replacement-text-nm {
            color: $color_replacement_nm;
        }
        .replacement-text-nxy {
            color: $color_replacement_nxy;
        }
        .replacement-text-tabc {
            color: $color_replacement_tabc;
        }
        .replacement-text-tijk {
            color: $color_replacement_tijk;
        }
        .replacement-text-nr {
            color: $color_replacement_nr;
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

#=item 

    # PARAGRAPH SEPARATION (txt, html)
    if (attr($root, 'newpar') and $format =~ /^(txt|html)$/) {
      $first_sent = 1;
      if ($first_par) {
        $first_par = 0;
      }
      else {
        $output .= "\n</p>\n" if $format eq 'html';
        # $output .= "\n\n" if $format eq 'txt'; # maybe not needed since using SpacesAfter and SpacesBefore
      }
      $output .= "<p>\n" if $format eq 'html';
    }

#=cut

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

=item maybe not needed since using SpacesAfter

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

=cut

    # PRINT THE SENTENCE TOKEN BY TOKEN
    my @nodes = sort {attr($a, 'ord') <=> attr($b, 'ord')} descendants($root);
    my $space_before = '';

    foreach my $node (@nodes) {

      next if attr($node, 'hidden'); # do not output hidden nodes (originally parts of multiword expressions such as multiword street names)
      
      # COLLECT INFO ABOUT THE TOKEN
      my $replacement = attr($node, 'replacement');
      my $form = $replacement // attr($node, 'form');
      my $classes = get_NameTag_marks($node) // '';

      my $span_start = '';
      my $span_end = '';
      my $info_span = '';

      if ($replacement and $format eq 'html') {
        my $span_class = 'replacement-text';
        if ($classes =~/\bgu\b/) {
          $span_class .= ' replacement-text-gu';
        }
        elsif ($classes =~/\bgq\b/) {
          $span_class .= ' replacement-text-gq';
        }
        elsif ($classes =~/\bgs\b/) {
          $span_class .= ' replacement-text-gs';
        }
        elsif ($classes =~/\bpf\b/) {
          $span_class .= ' replacement-text-pf';
        }
        elsif ($classes =~/\bps\b/) {
          $span_class .= ' replacement-text-ps';
        }
        elsif ($classes =~/\bah\b/) {
          $span_class .= ' replacement-text-ah';
        }
        elsif ($classes =~/\ba[xyz]\b/) {
          $span_class .= ' replacement-text-az';
        }
        elsif ($classes =~/\bme\b/) {
          $span_class .= ' replacement-text-me';
        }
        elsif ($classes =~/\bif\b/) {
          $span_class .= ' replacement-text-if';
        }
        elsif ($classes =~/\bnk\b/) {
          $span_class .= ' replacement-text-nk';
        }
        elsif ($classes =~/\bnl\b/) {
          $span_class .= ' replacement-text-nl';
        }
        elsif ($classes =~/\bnm\b/) {
          $span_class .= ' replacement-text-nm';
        }
        elsif ($classes =~/\bn[xy]\b/) {
          $span_class .= ' replacement-text-nxy';
        }
        elsif ($classes =~/\bt[abc]\b/) {
          $span_class .= ' replacement-text-tabc';
        }
        elsif ($classes =~/\bt[ijk]\b/) {
          $span_class .= ' replacement-text-tijk';
        }
        elsif ($classes =~/\bnr\b/) {
          $span_class .= ' replacement-text-nr';
        }
        $span_start = "<span class=\"$span_class\">";
        $span_end = '</span>';
      }
      
      if (($diff and $replacement) or ($add_NE and $classes and $replacement) or ($add_NE and $add_NE == 2 and $classes)) { # should the original form and/or NE class be displayed as well?
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
          $info_span .= get_original($node); # usually just attr($node, 'form') but more complex if hidden nodes below
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
        my $SpacesAfter = get_misc_value($node, 'SpacesAfter') // ''; # newlines etc. in the original text
        my $SpacesBefore = get_misc_value($node, 'SpacesBefore') // ''; # newlines etc. in the original text; seems to be sometimes used with presegmented input

        # handle extra spaces and newlines in SpaceBefore (seems to be sometimes used with presegmented input)
        if ($SpacesBefore =~ /^(\\s|\\r|\\n)+$/) { # SpacesBefore informs that there were newlines or extra spaces in the original text here
          if ($format eq 'html') {
            $SpacesBefore =~ s/\\r//g;
            while ($SpacesBefore =~ /\\s\\s/) {
              $SpacesBefore =~ s/\\s\\s/&nbsp; /;
            }
            $SpacesBefore =~ s/\\s/ /g;
            while ($SpacesBefore =~ /\\n\\n/) {
              $SpacesBefore =~ s/\\n\\n/\n<p><\/p>\\n/;
            }
            $SpacesBefore =~ s/\\n/\n<br>/g;            
          }
          else { # txt
            $SpacesBefore =~ s/\\r/\r/g;
            $SpacesBefore =~ s/\\n/\n/g;
            $SpacesBefore =~ s/\\s/ /g;
          }
          $output .= $SpacesBefore;          
        }

        $output .= "$space_before$span_start$form$span_end$info_span";

        $space_before = ($SpaceAfter eq 'No') ? '' : ' '; # this way there will not be space after the last token of the sentence

        # $output .= "($SpacesAfter)"; # debug info
        # handle extra spaces and newlines in SpaceAfter
        if ($SpacesAfter =~ /^(\\s|\\r|\\n)+$/) { # SpacesAfter informs that there were newlines or extra spaces in the original text here
          if ($format eq 'html') {
            $SpacesAfter =~ s/\\r//g;
            while ($SpacesAfter =~ /\\s\\s/) {
              $SpacesAfter =~ s/\\s\\s/&nbsp; /;
            }
            $SpacesAfter =~ s/\\s/ /g;
            while ($SpacesAfter =~ /\\n\\n/) {
              $SpacesAfter =~ s/\\n\\n/\n<\/p><p>\\n/;
            }
            $SpacesAfter =~ s/\\n/\n<br>/g;            
          }
          else { # txt
            $SpacesAfter =~ s/\\r/\r/g;
            $SpacesAfter =~ s/\\n/\n/g;
            $SpacesAfter =~ s/\\s/ /g;
          }
          $output .= $SpacesAfter;          
        }
        
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
  
  # All sentences processed

  if ($format eq 'html') {
    $output .= "\n</p>\n";
    $output .= "</body>\n";
    $output .= "</html>\n";
  }

  return $output;
  
} # get_output


=item get_original

Returns the original form of this node. Usually it is just attr($node, 'form') but sometimes it contains also hidden nodes from the subtree pointing to this node.

=cut

sub get_original {
  my $node = shift;
  my $ord = attr($node, 'ord');
  my @hidden_descendants = grep {attr($_, 'hidden') and attr($_, 'hidden') eq $ord} descendants($node);
  push(@hidden_descendants, $node);
  return surface_text(@hidden_descendants);
}


=item surface_text

Given array of nodes, give surface text they represent

=cut

sub surface_text {
  my @nodes = @_;
  my @ord_sorted = sort {attr($a, 'ord') <=> attr($b, 'ord')} @nodes;
  my $text = '';
  my $space_before = '';
  foreach my $token (@ord_sorted) {
    # mylog(0, "surface_text: processing token " . attr($token, 'form') . "\n");
    $text .= $space_before . attr($token, 'form');
    my $SpaceAfter = get_misc_value($token, 'SpaceAfter') // '';
    my $SpaceAfterOrig = get_misc_value($token, 'SpaceAfterOrig') // '';
    $space_before = ($SpaceAfter eq 'No' and $SpaceAfterOrig ne 'Yes') ? '' : ' ';
  }
  return $text;
}


=item get_stats

Produces an html document with statistics about the anonymization, using info from these variables:
my $sentences_count;
my $tokens_count;
my $processing_time;

=cut

sub get_stats {
  my $stats = "<html>\n";
  $stats .= <<END_HEAD;
<head>
  <style>
    h3 {
      margin-top: 5px;
    }
    table {
      border-collapse: collapse;
    }
    table, th, td {
      border: 1px solid black;
    }
    th, td {
      text-align: left;
      padding-left: 2mm;
      padding-right: 2mm;
    }
    td:last-child {
      text-align: right;
      padding-right: 20px;
    }
  </style>
</head>
END_HEAD

  $stats .= "<body>\n";

  $stats .= "<h3>MasKIT version $VER</h3>\n";
  
  $stats .= "<p>Number of sentences: $sentences_count\n";
  $stats .= "<br/>Number of tokens: $tokens_count\n";
  my $rounded_time = sprintf("%.1f", $processing_time);
  $stats .= "<br/>Processing time: $rounded_time sec.\n";
  $stats .= "</p>\n";

  $stats .= "$DESC\n";
  
  $stats .= "</body>\n";
  $stats .= "</html>\n";

  return $stats;
}


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


# the following function is modified from Jan Štěpánek's UD TrEd extension
sub _create_structure {
    my ($root) = @_;
    my %node_by_ord = map +(attr($_, 'ord') => $_), $root->getAllChildren;
    # mylog(0, "_create_structure: \%node_by_ord:\n");
    foreach my $ord (sort {$a <=> $b} keys(%node_by_ord)) {
      # mylog(0, "_create_structure:   - $ord: " . attr($node_by_ord{$ord}, 'form') . "\n");
    }
    foreach my $node ($root->getAllChildren) {
        my $head = attr($node, 'head');
        # mylog(0, "_create_structure: head $head\n");
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
	mylog(0, "$ord$pre$form\n");
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

Calling UDPipe REST API; the input to be processed is passed in the first argument
The second argument ('segment'/'parse') chooses between the two tasks.
Segmentation expects plain text as input, the parsing expects segmented conll-u data.
Returns the output in UD CONLL format

=cut

sub call_udpipe {
    my ($text, $task) = @_;

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
    #my $url = "http://lindat.mff.cuni.cz/services/udpipe/api/process?$input$model$tagger$parser";
    my $url = "$udpipe_service_url/process?$input$model$tagger$parser";
    mylog(2, "Call UDPipe: URL=$url\n");
    
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
        mylog(2, "call_udpipe: URL: $url\n");
        mylog(1, "call_udpipe: Text: $text\n");
        mylog(2, "call_udpipe: Chyba: " . $res->status_line . "\n");
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
      #mylog(0, "Processing line $line\n");
      $conll_part .= $line . "\n";
      if ($line =~ /^\s*$/) { # empty line means end of sentence
        #mylog(0, "Found an empty line.\n");
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

    # Funkční volání metodou POST, i když podivně kombinuje URL-encoded s POST

    # Nastavení URL pro volání REST::API s parametry
    my $url = "$nametag_service_url/recognize?input=conllu&output=conllu-ne";
    mylog(2, "Call NameTag: URL=$url\n");

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
        # mylog(0, "NameTag result:\n$result\n");
        return $result;
    } else {
        mylog(2, "call_nametag_part: URL: $url\n");
        mylog(2, "call_nametag_part: Chyba: " . $res->status_line . "\n");
        return $conll; 
    }
}

