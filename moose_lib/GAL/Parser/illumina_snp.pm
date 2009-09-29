package GAL::Parser::illumina_snp;

use strict;
use vars qw($VERSION);


$VERSION = '0.01';
use base qw(GAL::Parser);

=head1 NAME

GAL::Parser::illumina_snp - <One line description of module's purpose here>

=head1 VERSION

This document describes GAL::Parser::illumina_snp version 0.01

=head1 SYNOPSIS

     use GAL::Parser::illumina_snp;

=for author to fill in:
     Brief code example(s) here showing commonest usage(s).
     This section will be as far as many users bother reading
     so make it as educational and exemplary as possible.

=head1 DESCRIPTION

=for author to fill in:
     Write a full description of the module and its features here.
     Use subsections (=head2, =head3) as appropriate.

=head1 METHODS

=cut

#-----------------------------------------------------------------------------

=head2

     Title   : new
     Usage   : GAL::Parser::illumina_snp->new();
     Function: Creates a illumina_snp object;
     Returns : A illumina_snp object
     Args    :

=cut

sub new {
	my ($class, @args) = @_;
	my $self = $class->SUPER::new(@args);

	return $self;
}

#-----------------------------------------------------------------------------

sub _initialize_args {
	my ($self, @args) = @_;

	$self->SUPER::_initialize_args(@args);

	my $args = $self->prepare_args(@args);

	my @valid_attributes = qw();

	$self->fields([qw(chromosome location ref_allele var_alleles id
                          total_reads read_alleles ref_reads var_reads)]);

	$self->set_attributes($args, @valid_attributes);

}

#-----------------------------------------------------------------------------

=head2 parse_record

 Title   : parse_record
 Usage   : $a = $self->parse_record();
grep {$_ ne $reference_allele} Function: Parse the data from a record.
 Returns : A hash ref needed by Feature.pm to create a Feature object
 Args    : A hash ref of fields that this sub can understand (In this case GFF3).

=cut

sub parse_record {
	my ($self, $record) = @_;

	# $record is a hash reference that contains the keys assigned
	# in the $self->fields call in _initialize_args above

	# Fill in the first 8 columns for GFF3
	# See http://www.sequenceontology.org/resources/gff3.html for details.
	my $id         = $record->{id};
	my $seqid      = $record->{chromosome};
	my $source     = 'Illumina';
	my $type       = 'SNP';
	my $start      = $record->{location};
	my $end        = $record->{location};
	my $score      = '.';
	my $strand     = '.';
	my $phase      = '.';

	# Create the attributes hash

	# Het with ref: get var_alleles and remove ref.  ref_reads and var_reads OK
	# chr10   56397   C       CT      rs12262442      28      C/T     17      11
	# chr10   61776   T       CT      rs61838967      15      T/C     7       8
	# chr10   65803   T       CT      KOREFSNP1       27      T/C     19      8
	# chr10   68106   C       AC      KOREFSNP2       43      C/A     22      21
	# chr10   84136   C       CT      rs4607995       24      C/T     10      13
	# chr10   84238   A       AT      rs10904041      22      A/T     5       16

	# Het but not ref: get var_alleles.  assign var_reads to correct var and calculate alter_var_reads from total - var_reads
	# chr10   12625631        A       GT      rs2815636       42      A/G     0       21
	# chr10   13864035        A       CT      rs5025431       27      A/T     0       15
	# chr10   14292681        G       AC      rs11528656      29      G/A     0       18
	# chr10   14771944        C       AG      rs3107794       29      C/G     0       15
	# chr10   15075637        A       CG      rs9731518       29      A/G     4       16

	# Homozygous get var_alleles and use only one.  ref_reads and var_reads OK
	# chr10   168434  T       GG      rs7089889       20      T/G     0       20
	# chr10   173151  T       CC      rs7476951       19      T/C     0       19
	# chr10   175171  G       TT      rs7898275       25      G/T     0       25
	# chr10   175358  C       TT      rs7910845       26      C/T     0       26

	# $self->fields([qw(chromosome location ref_allele var_alleles id total_reads read_alleles ref_reads var_reads)]);

	# Assign the reference and variant allele sequences:
	# reference_allele=A
	# variant_allele=G
	my $reference_allele = $record->{ref_allele};
	my %variant_alleles  = map {$_, 1} split //, $record->{var_alleles};
	my @variant_alleles = keys %variant_alleles; # grep {$_ ne $reference_allele}

	# Assign the reference and variant allele read counts;
	# reference_reads=A:7
	# variant_reads=G:8

	my $total_reads = $record->{total_reads};
	my $reference_reads = "$reference_allele:" . $record->{ref_reads};

	# chr10   56397   C       CT      rs12262442      28      C/T     17      11
	my @read_alleles = split m|/|, $record->{read_alleles};
	my %read_counts = ($read_alleles[0] => $record->{ref_reads},
			   $read_alleles[1] => $record->{var_reads},
			   );

	my @variant_reads = map {"$_:" . ($read_counts{$_} || $total_reads - $record->{var_reads})} @variant_alleles;

	# if (scalar @variant_alleles > 1) {
	# 	my @read_alleles = split m|/|, $record->{read_alleles};
	# 	my $alt_allele;
	# 	for my $this_allele (@variant_alleles) {
	# 		next if grep {$_ eq $this_allele} @read_alleles;
	# 		$alt_allele = $this_allele;
	# 	}
	# 	my $var_allele = $variant_alleles[0] ne $alt_allele ? $variant_alleles[0] : $variant_alleles[1];
	# 	my $var_reads = $record->{var_reads};
	# 	my $alt_reads  = $total_reads - $record->{ref_reads} - $record->{var_reads};
	# 	push @variant_reads, "$var_allele:$var_reads";
	# 	push @variant_reads, "$alt_allele:$alt_reads";
	# }
	# else {
	# 	push @variant_reads, ($variant_alleles[0] . ':' . $record->{var_reads});
	# }

	# Assign the total number of reads covering this position:
	# total_reads=16

	# Assign the genotype:
	# genotype=homozygous
	my $genotype = $self->get_genotype($reference_allele, \@variant_alleles);

	# Assign the probability that the genotype call is correct:
	# genotype_probability=0.667

	# my ($genotype, $variant_type) = $record->{variant_type} =~ /(.*?)_(.*)/;

	# Any quality score given for this variant should be assigned
	# to $score above (column 6 in GFF3).  Here you can assign a
	# name for the type of score or algorithm used to calculate
	# the sscore (e.g. phred_like, clcbio, illumina).
	# score_type = 'illumina_snp';

	# Create the attribute hash reference.  Note that all values
	# are array references - even those that could only ever have
	# one value.  This is for consistency in the interface to
	# Features.pm and it's subclasses.  Suggested keys include
	# (from the GFF3 spec), but are not limited to: ID, Name,
	# Alias, Parent, Target, Gap, Derives_from, Note, Dbxref and
	# Ontology_term. Note that attribute names are case
	# sensitive. "Parent" is not the same as "parent". All
	# attributes that begin with an uppercase letter are reserved
	# for later use. Attributes that begin with a lowercase letter
	# can be used freely by applications.

	# For sequence_alteration features the suggested keys include:
	# reference_allele, variant_allele, reference_reads, variant_reads
	# total_reads, genotype, genotype_probability and score type.
	my $attributes = {reference_allele => [$reference_allele],
			  variant_allele   => \@variant_alleles,
			  reference_reads  => [$reference_reads],
			  variant_reads    => \@variant_reads,
			  total_reads      => [$total_reads],
			  genotype         => [$genotype],
			  ID               => [$id],
			 };

	my $feature_data = {id         => $id,
			    seqid      => $seqid,
			    source     => $source,
			    type       => $type,
			    start      => $start,
			    end        => $end,
			    score      => $score,
			    strand     => $strand,
			    phase      => $phase,
			    attributes => $attributes,
			   };

	return $feature_data;
}

#-----------------------------------------------------------------------------

=head2 foo

 Title   : foo
 Usage   : $a = $self->foo();
 Function: Get/Set the value of foo.
 Returns : The value of foo.
 Args    : A value to set foo to.

=cut

sub foo {
	my ($self, $value) = @_;
	$self->{foo} = $value if defined $value;
	return $self->{foo};
}

#-----------------------------------------------------------------------------

=head1 DIAGNOSTICS

=for author to fill in:
     List every single error and warning message that the module can
     generate (even the ones that will "never happen"), with a full
     explanation of each problem, one or more likely causes, and any
     suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back

=head1 CONFIGURATION AND ENVIRONMENT

<GAL::Parser::illumina_snp> requires no configuration files or environment variables.

=head1 DEPENDENCIES

None.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to:
barry.moore@genetics.utah.edu

=head1 AUTHOR

Barry Moore <barry.moore@genetics.utah.edu>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009, Barry Moore <barry.moore@genetics.utah.edu>.  All rights reserved.

    This module is free software; you can redistribute it and/or
    modify it under the same terms as Perl itself.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1;
