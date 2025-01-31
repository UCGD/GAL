#!/usr/bin/perl
use strict;

use Test::More;

BEGIN {
	use lib '../../';
	use_ok('GAL::Schema::Result::Feature::transcript');
        use_ok('GAL::Annotation');
}

my $path = $0;
$path =~ s/[^\/]+$//;
$path ||= '.';
chdir($path);

my $object = GAL::Schema::Result::Feature::transcript->new();
isa_ok($object, 'GAL::Schema::Result::Feature::transcript');

system('rm data/dmel-4-r5.46.genes.sqlite') if
  -e 'data/dmel-4-r5.46.genes.sqlite';

ok(my $schema = GAL::Annotation->new('data/dmel-4-r5.46.genes.gff',
                                     'data/dmel-4-chromosome-r5.46.fasta'),
   '$schema = GAL::Annotation->new("dmel.gff", "dmel.fasta"');


ok(my $features = $schema->features, '$features = $schema->features');

ok(my $transcripts = $features->search({type => [qw(mRNA ncRNA)]}),
   '$features->search({type => [qw(mRNA ncRNA)]})');

#-------------------------------------------------------------------------------
# Test $transcript->exons
#-------------------------------------------------------------------------------
my $count;
TRANSCRIPT:
while (my $transcript = $transcripts->next) {
  for my $exon ($transcript->exons) {
    ok(my $locus = $exon->locus, '$exon->locus');
    #print "$locus\n";
  }
  last TRANSCRIPT if ++$count > 20;
}

#-------------------------------------------------------------------------------
# Test $transcript->infer_introns
# Test $transcript->introns
#-------------------------------------------------------------------------------

$count = 0;
$transcripts->reset;
my %seen_intron_coords;
my %inf_intron_coords;
while (my $transcript = $transcripts->next) {
  my @these_exons;
  for my $exon (sort {$a->start <=> $b->start} $transcript->exons) {
    push @these_exons, $exon->get_values(qw(start end));
  }
  shift @these_exons;
  pop   @these_exons;
  map {$seen_intron_coords{$_}++} @these_exons;
  ok($transcript->infer_introns, '$transcript->infer_introns');
  my $icount;
  for my $intron ($transcript->introns) {
    ok(my($start, $end) = $intron->get_values(qw(start end)),
       '$intron->get_values(qw(start end))');
    $inf_intron_coords{$start}++;
    $inf_intron_coords{$end}++;
    $icount++;
  }
  last if $count++ > 50;
}
my $seen_introns    = join ',', sort keys %seen_intron_coords;
my $infered_introns = join ',', sort keys %inf_intron_coords;
ok($seen_introns eq $infered_introns, '$seen_introns eq $infered_introns,');

#-------------------------------------------------------------------------------
# Test $transcript->mature_seq_genomic
#-------------------------------------------------------------------------------

  my %correct_seq = ('FBtr0299529' => 'CGACGTGGTGAAATTGTTGCTGTTACTGGCGATGGTGTGAATGACTCTCCGGCATTAAAAAGAGCCGATATTGGCGTTGCAATGGGTATTTCTGGATCTGACGTTTCTAAGCAGGCGGCAGATATGATTCTATTGGATGACAACTTTGCATCAATTGTTGTTGGTATTGAAGAGGGGCGGATTATTTTCGATAATCTTAAAAAGTCCATCGCATATACCTTGACTTCAAATCTTCCTGAAATAGTGCCGTTTTTATTTTTTGTGATATTTGATATACCTTTAGCTCTGGGCACTATAGCAATTCTATGCATCGATATCGGCACTGATATGCTTCCGGCAATATCGCTAGCTTATGAAAAAGCTGAATCTGATATAATGGCGCGTATGCCAAGAGATCCGTTTGAAGACCGTTTGGTAAATAAAAAGTTAATTCTAATGGCTTATTTGCAAATTGGAGTTATACAAACAGTAGCATGTTTTTTTACTTTTTTTGCTATAATGGCAGAACATGGATTCCCCCCCTCCAGACTTAAAGGAATTCGAGAAGACTGGGACTCAAAAAATGTAGAAGACCTTGAAGATGGCTACGGACAAGAATGGACCTACAGGGAACGTAAAGTTCTTGAATATACAGCAGGCACCGGGTTTTTTGTGTCGATTGTTGTAACACAGGTTTTTGACCTTTTAATATGCAAAACTCGTCGAAACTCAATATTGCAACAAGGTATGGGCAATCATGTACTTAACTTTGCTTTGGTTCTTGAATTCATCATTGCCTGTCTACTTTGCTATGTTCCAGTATTTGAAAAAACATTGAGAATGTATTCCATCAAATTTATTTGGTGGATATATGCGTTCCCTTTTGGTCTATTAATTTTCTTTTTTGATGAAAGTCGTCGATTTCTAATAAGAAGAAATCCAGGTGGATGGGTGGAACAAGAAACTTATTATTAATTACAGCTATGTATCCAGTTACACCAATAAATTTCCGTCGCCGT',
                 'FBtr0308297' => 'GACGGGTATATAGAGTTTTCCCTTATTTTAATAATCTAGGGTCGCCAGTTTGTCCGTCAGTTCTTCGCTAACGAAGTTCGCTGTTGGCTCGGTATCGACTGTGTAGTCTAGACTCCCTTCGTTGGTCCTCCTGCTGCGTTTCGTCCTTGCTAAGGGCTTTGCCCTCTGGCTTCGTAGTCTTCCTGGTGTGTAGGGTCTATTTTGTTTCCATCTCTGAGTAAGTATAAATAAATTTGGCTTGATTTTTATACTTTAGAGAGCCGTAACGGATAATGAAATAACGCCCCCATACTCTAGATATAGTTTTATCAACAAAGAATTAACCGTATATTGTAATTTGACAAAAATGTTGTATATTTTTCTTCGTAATAAGATCGATAGGGCATAGTTCTTATAATACAAAGCCGGCTTCTCTTACATACGTATAAGTCCATACATTTTTTAAACTAAAATTTATAATTTTTTTGACAATTGTAAATAAATTGTTATCTTGCTAAAAAATAAAAAAGTTACAAAAATTTTTAAAAAATCATATTGATGTCAGCAATTAGATGTGCAATCACCATCTAGTGTAGCAGCAACATTTCCTAATTTTCGTGAAAGATGCATCTTTCGGCAATTAATATCAGTTTCAAGTGATTCCATAATCTGATCCTTATATTTAGTTATATAAATGTATAACTCTTTTAATGCAGAAATAGTATCAAACTCTTCGTTTTGCCTTACTGATAGCTGTTGCATAGCTGTACTCATTTCCTGGTCGCTTATTTGTGGAAGCCTTGATACATCGCGGTAAAACTCTTTGACCATAATTCTATAGTTTGGAATATCCTTAGCAAACAGCAACTTATTCGACGGCGAATCTTTTCCAAGTCTGTGCTCTGATGTTGAACAAGCGTCCATAAATGTTTGTGCAATGACACTTAAACAGGAATCAACGCTGTATGTTTTATTTACATCAAATATAAAATCCGGATTTTTTATAAAATTAACCCAGAATCGAAGGGGCAAACAATTTGACTTCCAAGCGTGCACAATATCAGTATCAGCAATATCATGGCGTCGCGCAGCTTCATCAAGTAAGTCAAAGAGCCATTTAACGGCAGGTGGCAACTCCTCATTAACAGTTAAAATAATTGAGAAAAAATCATCAACAAATTTTTGTATAGTTCCTTTTGTGGCCAGAAGACGTGTAAGGTAAACTTCTGGTATTGTTTTGTTCACCCTGTCATTACAATTATTAACGACATGCGATTGAAATGCTGGTGATCCTCCGGATAACACGGAATTTTTAATGTTCATATAATGATCAGGTATATTGGGCTTAACAAGATGGTAAACCCGGGGCTGCTGCAAACCTGATTCGATATCATTATTAATTATAATATGACTTTGCGAATTGTTTATAAAATAAAAATTGTGGTATGGTGCCGAATTTTGGTTTTTACTGTATGGTATATGATAATTATCATTTTGACGTGCAATTAGTGACATTACTGCAGATTCTTTGACTCCATAATGAGCTAATGTGTTAAGGCGCTTCCATCCGTTAACGGTTTTGGTTGTCAAGTCTTCATCTTGTAATGTAAGATGACCTCCTCGGCCGTGCCTCCATTCTAAGTCTACTTCGTTTACAGATGGCCTCATAGAGAAAGGAGTGTTTTTAAAAATTGCGTCGAGGATTTTAAGCTTAACTTGAGAAATGGTATCCCAATCGTTAACGCGACATTGGACTTTTTCATCAAGATCATCTTGTAAAATATGCAATATTACAACAGAATGGGTAACTTGTTCATGCAGAAGACGTTCTTCTGAAAGGGAGTAACGGGCATCGTTGGTTATTGCGTCCACTAAACCCTTTTCAATTTGATGCTTTATTGCTTTGAAGAGCAAAAATAAATTTGATCCGGCGTACTCTTTCAGGTAATCGTACATACAAATTGCTAGGTAGTTGGTCAACATTTTTTCAACAACGCTTTCAGTACGCCTTAGCATCAGCTGAGGATGTTTGCTGGCAAGTGATTTATCTATCAAACGTAATAAAAGGGACTTCAAAATTTCCGTGGCATATTCCATCTTGTTCATTAAAACAACCATTATTAATGAGGCAACGTTAACTCGGTCTCTAATAGAAAATGATGAACGTTGAGCTTCTAATGTTTCTATGAACATTAATAAAAAATATTTATTGCCAATCAGTTGTTCAAATTGTACCATAGCTGCGTCATAGTTAGTCTGTGGGCTACCTTCACGAAATTTTGGAGAATTTAAAATAGGATGATCTGATACACCAGGGAAAAACACCTTCATAATATAGTTGACGTGATCTAAAGTTGGTATGCCTGTGCTCTCCAAATCTGCTGTTAGGTCGGTCATGTCCGTTTGGAGCTCAGCGAATGCCTGTTTACACTCAGAACGTACGTTGCTTTCTAATGTAATCATCTGTATCTGAATACGTTTATACTCGCGTTCTGCTTGTGTTGATTTCCTTCTGAATATTATAAGTACAATTACAAAAACAACGACCAGAAGTGCTACCGTTAATATGCCGACTAACAAGGCATGTGAGAAAACATAGGGTTTATTTAAATCATACTTAAGATATCCTATTACAAAACGAAGATTTCGACCTACTTTAACGACAACAAGAGGTAAATCAGTTGATTGATCCACACCATTTTCATCAGTTGGAAGTGGTTGTTGCTCCGGCGGAATGCATAAAAGTTGGTTAAGTGCCAGGCTGGTAATATTGCATTGGGAAGTTCCAATAGTTACATTTACATCGTACTCATCAGCTGCCAAGTTTAATAGCTCGCCTTCTATGACCAAGCTGTCACCCTTGTAGAGTTTAACGCCGTCGTTGGGAAATGGCAAATATTTTGGGTCTGCTAAATAGACAATAGTGCTCCTTATGTCATGAAAATATTTATTCAAGTTTCGAACTAGTTGTACATTGTCCATTACAAAACTTAGTTGTAAGTTTAATTGAGTTTCATGAACCTTAACGAATGTGGTGACGTCCATATTATTGTTAACAAAATAGTTGGCTGAAGATCCTGCATTTGTGTATAAGCGAAAAGTGTCTCCAAAGTCGGCTCGCCGCTTTTTTCTATCATATTCATTTTTATACCTGGTTTCAGTTTGAAACGAAGAATTTTGTAAGTGCAATTCAGTATCCATCTTTCTGTTCGTCTTTTTAAAAGTCTCAAATTTGTAATTTACAGGAGGAGATGGACATTCCATTTGATTAGAGTTGATCACCACACAAGATGTTTTATTTACTCTTTCATTGTCATAAAACACTTCTAGTTCAGGTTTTTGGATGGAATTAAGATATATTCCATGAACGGTGAGGACTCGACCACCACTTTTAAAACTACGCAATGGCTTAATTTGCATTATACGCGGGTCCTGTGTATAGTTAAAAATAGAGCAGGGTTGCCGTGGTAGCGAACGGAGTTGATAAGAACCAAAATTACTTCGAGTCGGATTTGTATTGGTAATGCTTGGGGTTGAGATCTGGCATTCTAGCGTTCTGTTCGCACCATCAATAACTAGATGAAGGGACCGTATTGGTTCAGGTTGGGTCGCTTCTGATGTAGTACAACTAACTTGGGATGATGAAGCTTGTGTAACATCTATATGACACTCATACTCATCTAAAAATGCTCGCATAGTTGAGCCAATGTTCAAAAACTTCCCAATTAAAGACAATTGTGTCCCTCCCGACCTAGGGCCAATTGTGGGATATAAACCTGTTAACAGCACATTCTTAAAATGAAACTGAACACTTGATTCAGTAAACCCTGCATCATTTGCAACTTTTATGGGTGCAGACATTTCGTACAGTGATGCTCCAGTCCGGCATTCAATTTTTACCGATATTTGATAATTTTCTAGTTCACAAGGCACAGAACCAATAAATATTTTGCCACGAACATCTTCCTCCCTTATGCCCAAATTACTTCCTTCAATTGTAATAAGAGTTCCACCCTCGACTGGCCCAGATAATGGTTTAATAATATCAATCCGTGGTAATGGGCACTCGTTTTCTATAGCGGATTTAGATCCTGAGCTGATAGAATTTTTATCAGCTATGCAAGTTTCATTATATACACATGAGTTGCTGCACCAAGCACATTTATATTTTGGATCTCGAGTTACGCACAAACTGCAATCAGGGTGTTCCCGATGGGAGCCCAACACGTCACACTTGTATAATGTAACAATTGCGGTGTCCACATAATGCTGGAAGTTCCATGTAACTACAACCTTCGCCTGATATTCATGTGTATTAATCTCGTAGAAATATGGTGTTTTTTCGCAAACTACAATTTTATTTGACTCAACGTGAGCAGGGAGTAGCATCTGAGCAGCTTCAATATGTATTGTACATAAAAAACCAGCATGTGCGCTCTTGGGTTTTGGTAAATTTTCAATCTCTAGCCGAATTTCTATTGGCACTCTTACGGGTAGAAGTATTTCCGGACGATTTTTTTTTAAGTGGGGGCAGTGACCAACAGTACTTACAGCATTTTCTATGTTACGGCATTGCAAAGACTTGTGAACGCACTTATTATCAAAAATACACCAGTTGCAACCCCAGGAACTTTGTAGACACTCCTGGCAATTTCCATGATGTGAGCAGTCAAAAAAAGCAAAATTCCTTGATACAAAATCCTTATTTGTCTCCGAACTTCTTACTGACAATGGCACCAAAATATGATCAGTGTTTGTTGGTATTAATGGTCTTTCATCTAATGGGGGAGTAGCACATCCGAGTCCGTTTTCCAGAATTTCGGCATCAATGGGGGTGGAATTTCCAAAAACACATCGGTATTTTGCATTAAAAGGTTCGGGCAAAGTTCGAATTATTAAATGCAGGTGCGATAATTCAGAAATTGGTATTTTCTCTGGGATAATAGATTCAAATTCTATGCATTGCTGTCCACTACCTAATGAAAGCCATCTCGACGCAGATGTATCTCGCTGGCATGTTGATCGTACAGTGCACCGCTTCTCCAAGGAACACCATCCACAAAAAGGATCCCGAGACTCTAAGCAAGCGGAACAATTCGTGTACACAGAACAGTGTTCGATTCTAAGCTTAGTTATTTTTCGTTGAGAAAGTACGTAAAGAAAATCTTTTTTTGGCGACATCATTGTATTTGGTAGTATACGATTTCCAGCATCCACAACTATTTCCTCGTACTCGCCCGGACTTTGGCCAGATAATAAAACTTTTTTGATTACTCCCATGTTCGTTCCAAGAAATGCAAGAGAATGCTGCTGATCAGTCGTTGAAGTTGCTGTGACTGACGTAACTGAAACATTATCAAAATGAAAAAGTGCGTGTGCAGTGATTGGGGATACTCCGCTTATTTTAAGTCCCACAGAGCAAAAGTTGTAAATGTTACCGAGCGAACCAACTATTGGACATCTGCCATCATTAATGGTGCCGGATATATAGCCCAAATTTCGATCTTTTGTGGTTCCGTTAAAACACAGATGGATATTTTCAATGAACATGTCTTCAATATCTTTAATGCTATATATACACATAGCAGACTTACTTTCTGGCTGATTACTTATTTCTCTTGAGGGCGAAAAAACCGTTACTAAAACGTGATCGTCTTTTTTTATGCCCATTTTTTGCGCCAATTTGTGGCTGGCTGGAGTTACTTTCGCATCCCTTACAATATTGTAGTCAACATTGTTTTCAGTTGCAGTGCATTGAACAGTTATTTCAGTATAGCTGTCGTAATTAGGATCTGTAATGCAAATGCGTGCCAAGCGTGTTACATAACCGGCCTCATCAGCTAAATGTGATTTTTTTTGAACAATTATGAAGTACGCATATTCAGAAGAATTAAAGCCGTAAATATAATCGACTAGAAAATGATCCCGATATTTTACATCGATATTTATAATTGACTGCTGTATTGAAAATTCAGCATAGTTTAAATCATCAAGTCGGCGGGACGAAATGGCTGGCACGTCATGACGATAATCACCAACATTCGTAAATGTTGTCCCCACATATAAAATATCCTCTTCTTTCCACGCATATCTCGCCGGACCTACAAATGCATATGTAGACGCGTTTTCATCGTTAGCAGCCAATGGAACTGCAAAAAACTGGGGCGTTGCCGGAAAACGTGGCAGGCTGTAAATTTCGCAGGCTCCTTGTCGAATGCTTCCACACGCTATGAGAATACCATCGTGAGCGTAGCTTACTACTAGAATTTTGTTGAAGTTATTGACAAGCGATGTCTCAATATCTTCCGGACAGCCTCCAGCGTGACATTGCGGGGAATCATGTAACGGCCCAGTAACAGCCTCGGCCAGCACTCGAAGGTTTTCGTTAAGTTTAAGTATTTTATTTGTAGCACCCGCAAACAAAACATTGTGCATAAAGTCGAAGCTCATGTGAGTAAAATAATTTTTAGATTGAGAGTCTCTAACACTTTCTATATTGTTTCCAATTGATCGATTGCCATAGCTGGAAGCTGTTGATTGAACTGGTATTGATGGCAAGTTAAACTGGGCGACTATGTCATTTAAGGGAGATAACGCCTGAGCCGGCAGTTCTTCAATGCAGTTAACGCAATAATGCTGAGAACCGAGTATGATAATAATACACAGTACATGTAAAACATGTATAATGTTTGCACAATACAATTCCTTTCGCAACATATTTATTTGTGGTTTTGTGTATGATCAGTTTGTAGTTGAGTTTGGGCATCAATTCCCCATATGTCATTTTTATTATTATTTAGCTCTACATTCTCTCTCCTTAATATATAAACTTTTTAATATCGATTGAATTTAATGCGAATTAATTTTATATGCCGCTGATTCACTGTAGGTGCATAAATATTTTTAAATTAAAATGATCCATTTGGCTATTTTAGGTTTAGCGCATTTTTTATAAGGTTGTTTAACACAAAAAATCGATTAGTCAATGTAAACAAATATTTATTTAAAAAAAACTTCTTAGGCAACGCTCAAACGTTGTGTGTACACTATCAGTCCTAGAGCAGATTATTA'
                );

$count = 0;
$transcripts->reset;
while (my $transcript = $transcripts->next) {
  ok(my $seq = $transcript->mature_seq_genomic,
     '$transcript->mature_seq_genomic');
  ok($seq =~ /^[ATGCN]+$/, '$seq =~ /^[ATGCN]+$/');
  my $feature_id = $transcript->feature_id;
  if (exists $correct_seq{$feature_id}) {
    ok($seq eq $correct_seq{$feature_id}, 'mature_seq_genomic is correct');
  }
  last if $count++ > 10;
}

#-------------------------------------------------------------------------------
# Test $transcript->mature_seq
#-------------------------------------------------------------------------------

$correct_seq{'FBtr0308297'} = 'TAATAATCTGCTCTAGGACTGATAGTGTACACACAACGTTTGAGCGTTGCCTAAGAAGTTTTTTTTAAATAAATATTTGTTTACATTGACTAATCGATTTTTTGTGTTAAACAACCTTATAAAAAATGCGCTAAACCTAAAATAGCCAAATGGATCATTTTAATTTAAAAATATTTATGCACCTACAGTGAATCAGCGGCATATAAAATTAATTCGCATTAAATTCAATCGATATTAAAAAGTTTATATATTAAGGAGAGAGAATGTAGAGCTAAATAATAATAAAAATGACATATGGGGAATTGATGCCCAAACTCAACTACAAACTGATCATACACAAAACCACAAATAAATATGTTGCGAAAGGAATTGTATTGTGCAAACATTATACATGTTTTACATGTACTGTGTATTATTATCATACTCGGTTCTCAGCATTATTGCGTTAACTGCATTGAAGAACTGCCGGCTCAGGCGTTATCTCCCTTAAATGACATAGTCGCCCAGTTTAACTTGCCATCAATACCAGTTCAATCAACAGCTTCCAGCTATGGCAATCGATCAATTGGAAACAATATAGAAAGTGTTAGAGACTCTCAATCTAAAAATTATTTTACTCACATGAGCTTCGACTTTATGCACAATGTTTTGTTTGCGGGTGCTACAAATAAAATACTTAAACTTAACGAAAACCTTCGAGTGCTGGCCGAGGCTGTTACTGGGCCGTTACATGATTCCCCGCAATGTCACGCTGGAGGCTGTCCGGAAGATATTGAGACATCGCTTGTCAATAACTTCAACAAAATTCTAGTAGTAAGCTACGCTCACGATGGTATTCTCATAGCGTGTGGAAGCATTCGACAAGGAGCCTGCGAAATTTACAGCCTGCCACGTTTTCCGGCAACGCCCCAGTTTTTTGCAGTTCCATTGGCTGCTAACGATGAAAACGCGTCTACATATGCATTTGTAGGTCCGGCGAGATATGCGTGGAAAGAAGAGGATATTTTATATGTGGGGACAACATTTACGAATGTTGGTGATTATCGTCATGACGTGCCAGCCATTTCGTCCCGCCGACTTGATGATTTAAACTATGCTGAATTTTCAATACAGCAGTCAATTATAAATATCGATGTAAAATATCGGGATCATTTTCTAGTCGATTATATTTACGGCTTTAATTCTTCTGAATATGCGTACTTCATAATTGTTCAAAAAAAATCACATTTAGCTGATGAGGCCGGTTATGTAACACGCTTGGCACGCATTTGCATTACAGATCCTAATTACGACAGCTATACTGAAATAACTGTTCAATGCACTGCAACTGAAAACAATGTTGACTACAATATTGTAAGGGATGCGAAAGTAACTCCAGCCAGCCACAAATTGGCGCAAAAAATGGGCATAAAAAAAGACGATCACGTTTTAGTAACGGTTTTTTCGCCCTCAAGAGAAATAAGTAATCAGCCAGAAAGTAAGTCTGCTATGTGTATATATAGCATTAAAGATATTGAAGACATGTTCATTGAAAATATCCATCTGTGTTTTAACGGAACCACAAAAGATCGAAATTTGGGCTATATATCCGGCACCATTAATGATGGCAGATGTCCAATAGTTGGTTCGCTCGGTAACATTTACAACTTTTGCTCTGTGGGACTTAAAATAAGCGGAGTATCCCCAATCACTGCACACGCACTTTTTCATTTTGATAATGTTTCAGTTACGTCAGTCACAGCAACTTCAACGACTGATCAGCAGCATTCTCTTGCATTTCTTGGAACGAACATGGGAGTAATCAAAAAAGTTTTATTATCTGGCCAAAGTCCGGGCGAGTACGAGGAAATAGTTGTGGATGCTGGAAATCGTATACTACCAAATACAATGATGTCGCCAAAAAAAGATTTTCTTTACGTACTTTCTCAACGAAAAATAACTAAGCTTAGAATCGAACACTGTTCTGTGTACACGAATTGTTCCGCTTGCTTAGAGTCTCGGGATCCTTTTTGTGGATGGTGTTCCTTGGAGAAGCGGTGCACTGTACGATCAACATGCCAGCGAGATACATCTGCGTCGAGATGGCTTTCATTAGGTAGTGGACAGCAATGCATAGAATTTGAATCTATTATCCCAGAGAAAATACCAATTTCTGAATTATCGCACCTGCATTTAATAATTCGAACTTTGCCCGAACCTTTTAATGCAAAATACCGATGTGTTTTTGGAAATTCCACCCCCATTGATGCCGAAATTCTGGAAAACGGACTCGGATGTGCTACTCCCCCATTAGATGAAAGACCATTAATACCAACAAACACTGATCATATTTTGGTGCCATTGTCAGTAAGAAGTTCGGAGACAAATAAGGATTTTGTATCAAGGAATTTTGCTTTTTTTGACTGCTCACATCATGGAAATTGCCAGGAGTGTCTACAAAGTTCCTGGGGTTGCAACTGGTGTATTTTTGATAATAAGTGCGTTCACAAGTCTTTGCAATGCCGTAACATAGAAAATGCTGTAAGTACTGTTGGTCACTGCCCCCACTTAAAAAAAAATCGTCCGGAAATACTTCTACCCGTAAGAGTGCCAATAGAAATTCGGCTAGAGATTGAAAATTTACCAAAACCCAAGAGCGCACATGCTGGTTTTTTATGTACAATACATATTGAAGCTGCTCAGATGCTACTCCCTGCTCACGTTGAGTCAAATAAAATTGTAGTTTGCGAAAAAACACCATATTTCTACGAGATTAATACACATGAATATCAGGCGAAGGTTGTAGTTACATGGAACTTCCAGCATTATGTGGACACCGCAATTGTTACATTATACAAGTGTGACGTGTTGGGCTCCCATCGGGAACACCCTGATTGCAGTTTGTGCGTAACTCGAGATCCAAAATATAAATGTGCTTGGTGCAGCAACTCATGTGTATATAATGAAACTTGCATAGCTGATAAAAATTCTATCAGCTCAGGATCTAAATCCGCTATAGAAAACGAGTGCCCATTACCACGGATTGATATTATTAAACCATTATCTGGGCCAGTCGAGGGTGGAACTCTTATTACAATTGAAGGAAGTAATTTGGGCATAAGGGAGGAAGATGTTCGTGGCAAAATATTTATTGGTTCTGTGCCTTGTGAACTAGAAAATTATCAAATATCGGTAAAAATTGAATGCCGGACTGGAGCATCACTGTACGAAATGTCTGCACCCATAAAAGTTGCAAATGATGCAGGGTTTACTGAATCAAGTGTTCAGTTTCATTTTAAGAATGTGCTGTTAACAGGTTTATATCCCACAATTGGCCCTAGGTCGGGAGGGACACAATTGTCTTTAATTGGGAAGTTTTTGAACATTGGCTCAACTATGCGAGCATTTTTAGATGAGTATGAGTGTCATATAGATGTTACACAAGCTTCATCATCCCAAGTTAGTTGTACTACATCAGAAGCGACCCAACCTGAACCAATACGGTCCCTTCATCTAGTTATTGATGGTGCGAACAGAACGCTAGAATGCCAGATCTCAACCCCAAGCATTACCAATACAAATCCGACTCGAAGTAATTTTGGTTCTTATCAACTCCGTTCGCTACCACGGCAACCCTGCTCTATTTTTAACTATACACAGGACCCGCGTATAATGCAAATTAAGCCATTGCGTAGTTTTAAAAGTGGTGGTCGAGTCCTCACCGTTCATGGAATATATCTTAATTCCATCCAAAAACCTGAACTAGAAGTGTTTTATGACAATGAAAGAGTAAATAAAACATCTTGTGTGGTGATCAACTCTAATCAAATGGAATGTCCATCTCCTCCTGTAAATTACAAATTTGAGACTTTTAAAAAGACGAACAGAAAGATGGATACTGAATTGCACTTACAAAATTCTTCGTTTCAAACTGAAACCAGGTATAAAAATGAATATGATAGAAAAAAGCGGCGAGCCGACTTTGGAGACACTTTTCGCTTATACACAAATGCAGGATCTTCAGCCAACTATTTTGTTAACAATAATATGGACGTCACCACATTCGTTAAGGTTCATGAAACTCAATTAAACTTACAACTAAGTTTTGTAATGGACAATGTACAACTAGTTCGAAACTTGAATAAATATTTTCATGACATAAGGAGCACTATTGTCTATTTAGCAGACCCAAAATATTTGCCATTTCCCAACGACGGCGTTAAACTCTACAAGGGTGACAGCTTGGTCATAGAAGGCGAGCTATTAAACTTGGCAGCTGATGAGTACGATGTAAATGTAACTATTGGAACTTCCCAATGCAATATTACCAGCCTGGCACTTAACCAACTTTTATGCATTCCGCCGGAGCAACAACCACTTCCAACTGATGAAAATGGTGTGGATCAATCAACTGATTTACCTCTTGTTGTCGTTAAAGTAGGTCGAAATCTTCGTTTTGTAATAGGATATCTTAAGTATGATTTAAATAAACCCTATGTTTTCTCACATGCCTTGTTAGTCGGCATATTAACGGTAGCACTTCTGGTCGTTGTTTTTGTAATTGTACTTATAATATTCAGAAGGAAATCAACACAAGCAGAACGCGAGTATAAACGTATTCAGATACAGATGATTACATTAGAAAGCAACGTACGTTCTGAGTGTAAACAGGCATTCGCTGAGCTCCAAACGGACATGACCGACCTAACAGCAGATTTGGAGAGCACAGGCATACCAACTTTAGATCACGTCAACTATATTATGAAGGTGTTTTTCCCTGGTGTATCAGATCATCCTATTTTAAATTCTCCAAAATTTCGTGAAGGTAGCCCACAGACTAACTATGACGCAGCTATGGTACAATTTGAACAACTGATTGGCAATAAATATTTTTTATTAATGTTCATAGAAACATTAGAAGCTCAACGTTCATCATTTTCTATTAGAGACCGAGTTAACGTTGCCTCATTAATAATGGTTGTTTTAATGAACAAGATGGAATATGCCACGGAAATTTTGAAGTCCCTTTTATTACGTTTGATAGATAAATCACTTGCCAGCAAACATCCTCAGCTGATGCTAAGGCGTACTGAAAGCGTTGTTGAAAAAATGTTGACCAACTACCTAGCAATTTGTATGTACGATTACCTGAAAGAGTACGCCGGATCAAATTTATTTTTGCTCTTCAAAGCAATAAAGCATCAAATTGAAAAGGGTTTAGTGGACGCAATAACCAACGATGCCCGTTACTCCCTTTCAGAAGAACGTCTTCTGCATGAACAAGTTACCCATTCTGTTGTAATATTGCATATTTTACAAGATGATCTTGATGAAAAAGTCCAATGTCGCGTTAACGATTGGGATACCATTTCTCAAGTTAAGCTTAAAATCCTCGACGCAATTTTTAAAAACACTCCTTTCTCTATGAGGCCATCTGTAAACGAAGTAGACTTAGAATGGAGGCACGGCCGAGGAGGTCATCTTACATTACAAGATGAAGACTTGACAACCAAAACCGTTAACGGATGGAAGCGCCTTAACACATTAGCTCATTATGGAGTCAAAGAATCTGCAGTAATGTCACTAATTGCACGTCAAAATGATAATTATCATATACCATACAGTAAAAACCAAAATTCGGCACCATACCACAATTTTTATTTTATAAACAATTCGCAAAGTCATATTATAATTAATAATGATATCGAATCAGGTTTGCAGCAGCCCCGGGTTTACCATCTTGTTAAGCCCAATATACCTGATCATTATATGAACATTAAAAATTCCGTGTTATCCGGAGGATCACCAGCATTTCAATCGCATGTCGTTAATAATTGTAATGACAGGGTGAACAAAACAATACCAGAAGTTTACCTTACACGTCTTCTGGCCACAAAAGGAACTATACAAAAATTTGTTGATGATTTTTTCTCAATTATTTTAACTGTTAATGAGGAGTTGCCACCTGCCGTTAAATGGCTCTTTGACTTACTTGATGAAGCTGCGCGACGCCATGATATTGCTGATACTGATATTGTGCACGCTTGGAAGTCAAATTGTTTGCCCCTTCGATTCTGGGTTAATTTTATAAAAAATCCGGATTTTATATTTGATGTAAATAAAACATACAGCGTTGATTCCTGTTTAAGTGTCATTGCACAAACATTTATGGACGCTTGTTCAACATCAGAGCACAGACTTGGAAAAGATTCGCCGTCGAATAAGTTGCTGTTTGCTAAGGATATTCCAAACTATAGAATTATGGTCAAAGAGTTTTACCGCGATGTATCAAGGCTTCCACAAATAAGCGACCAGGAAATGAGTACAGCTATGCAACAGCTATCAGTAAGGCAAAACGAAGAGTTTGATACTATTTCTGCATTAAAAGAGTTATACATTTATATAACTAAATATAAGGATCAGATTATGGAATCACTTGAAACTGATATTAATTGCCGAAAGATGCATCTTTCACGAAAATTAGGAAATGTTGCTGCTACACTAGATGGTGATTGCACATCTAATTGCTGACATCAATATGATTTTTTAAAAATTTTTGTAACTTTTTTATTTTTTAGCAAGATAACAATTTATTTACAATTGTCAAAAAAATTATAAATTTTAGTTTAAAAAATGTATGGACTTATACGTATGTAAGAGAAGCCGGCTTTGTATTATAAGAACTATGCCCTATCGATCTTATTACGAAGAAAAATATACAACATTTTTGTCAAATTACAATATACGGTTAATTCTTTGTTGATAAAACTATATCTAGAGTATGGGGGCGTTATTTCATTATCCGTTACGGCTCTCTAAAGTATAAAAATCAAGCCAAATTTATTTATACTTACTCAGAGATGGAAACAAAATAGACCCTACACACCAGGAAGACTACGAAGCCAGAGGGCAAAGCCCTTAGCAAGGACGAAACGCAGCAGGAGGACCAACGAAGGGAGTCTAGACTACACAGTCGATACCGAGCCAACAGCGAACTTCGTTAGCGAAGAACTGACGGACAAACTGGCGACCCTAGATTATTAAAATAAGGGAAAACTCTATATACCCGTC';

$count = 0;
$transcripts->reset;
while (my $transcript = $transcripts->next) {
  ok(my $seq = $transcript->mature_seq,
     '$transcript->mature_seq');
  ok($seq =~ /^[ATGCN]+$/, '$seq =~ /^[ATGCN]+$/');
  my $feature_id = $transcript->feature_id;
  if (exists $correct_seq{$feature_id}) {
    ok($seq eq $correct_seq{$feature_id}, 'mature_seq is correct');
  }
  last if $count++ > 10;
}

#-------------------------------------------------------------------------------
# Test $transcript->length
#-------------------------------------------------------------------------------

my %correct_length = (FBtr0299529 => 998,
		      FBtr0308297 => 7050,
		      FBtr0089179 => 6716,
		      FBtr0306168 => 5191,
		      FBtr0089178 => 4941,
		      FBtr0308074 => 4874,
		      FBtr0308296 => 1349,
		      FBtr0089175 => 910,
		      FBtr0089176 => 854,
		      FBtr0089156 => 4123,
		      FBtr0089157 => 4055,
		      FBtr0089158 => 3997,
		     );

$count = 0;
$transcripts->reset;
while (my $transcript = $transcripts->next) {
  ok(my $length = $transcript->length,
     '$transcript->length');
  ok($length =~ /^[0-9]+$/, '$length =~ /^[0-9]+$/');
  my $feature_id = $transcript->feature_id;
  if (exists $correct_length{$feature_id}) {
    ok($length eq $correct_length{$feature_id}, 'length is correct');
  }
  # print $transcript->feature_id . " => $length\n";
  last if $count++ > 10;
}

#-------------------------------------------------------------------------------
# Test $transcript->coordinate_map
#-------------------------------------------------------------------------------

$count = 0;
$transcripts->reset;
while (my $transcript = $transcripts->next) {
  ok(my $map = $transcript->coordinate_map,
     '$transcript->coordinate_map');
  ok(ref $map eq 'HASH');
  last if $count++ > 100;
}

#-------------------------------------------------------------------------------
# Test $transcript->me2genome
# Test $transcript->genome2me
#-------------------------------------------------------------------------------

$count = 0;
$transcripts->reset;
while (my $transcript = $transcripts->next) {
  my $me1 = int(rand($transcript->length));
  ok(my ($g_cord) = $transcript->me2genome($me1),
     "\$transcript->me2genome($me1)");
  ok(my ($me2) = $transcript->genome2me($g_cord),
     "\$transcript->genome2me($g_cord)");
  ok($me1 == $me2, '$me1 == $me2');
  last if $count++ > 100;
}

#-------------------------------------------------------------------------------
# Test $transcript->AED
#-------------------------------------------------------------------------------

ok(my $genes = $features->search({type => 'gene'}),
   '$features->search({type =>"gene"})');

while (my $gene = $genes->next) {
  ok(my $mRNAs = $gene->mRNAs, '$gene->mRNAs');
  next unless $mRNAs->count > 1;
  ok(my $mRNA1 = $mRNAs->next, '$mRNAs->next');
  ok(my $mRNA2 = $mRNAs->next, '$mRNAs->next');
  ok(my $aed = $mRNA1->AED($mRNA2), '$mRNA1->AED($mRNA2)');
  print "$aed\n";
}

print '';

# To get a list of all of the subs and throws:
# Select an empty line and then: C-u M-| grep -nP '^sub ' ../Schema::Result::Feature::transcript.pm
# Select an empty line and then: C-u M-| grep -C2 -P '\>throw(' ../Schema::Result::Feature::transcript.pm




done_testing();

################################################################################
################################# Ways to Test #################################
################################################################################

__END__



=head3
# Various other ways to say "ok"
ok($this eq $that, $test_name);

is  ($this, $that,    $test_name);
isnt($this, $that,    $test_name);

# Rather than print STDERR "# here's what went wrong\n"
diag("here's what went wrong");

like  ($this, qr/that/, $test_name);
unlike($this, qr/that/, $test_name);

cmp_ok($this, '==', $that, $test_name);

is_deeply($complex_structure1, $complex_structure2, $test_name);

can_ok($module, @methods);
isa_ok($object, $class);

pass($test_name);
fail($test_name);

BAIL_OUT($why);
=cut
