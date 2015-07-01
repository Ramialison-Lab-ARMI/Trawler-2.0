#! usr/bin/perl

#==============================================================================
# Read and Set properties
#==============================================================================

use strict;
use warnings;
use Carp;
use File::Basename;
use File::Spec;
use File::Temp;
use Getopt::Long;

# Locate Trawler modules
use FindBin();
use lib "$FindBin::RealBin/../modules";
my $script_name = $FindBin::RealScript;

# Trawler Modules
use Trawler::Constants 1.0 qw(_read_config _tcst);
use Trawler::Utils 1.0 qw(_parse_seq_file _parse_cluster_file _reg_exp);

# START processing
print "\n## Running $script_name\n";
###############################################################################

my $file_motif;
my $file_sequences;
my $directory;
my $help;
my $org;

_read_config($FindBin::RealBin);
my %tcst = _tcst();

GetOptions(
'motif:s'     => \$file_motif,
'sequences:s' => \$file_sequences,
'directory=s' => \$directory,
'help:s'      => \$help,
'org=s'       => \$org,
);

my $counter = 0;

###############################################################################

if (!$file_motif || !$file_sequences) {
    
    print STDERR "\nUSAGE : \n \n perl pipeline_trawler_02_no_orthologs.pl  -motif [the complete path to the XX.cluster file from pipeline_trawler1.pl ]  -sequences [complete path to the sequences sequence in fasta format (sample file in pipeline trawler1 ) ] -directory [path to temporary directory] -org [organism used in analysis to retrieve pahstonscores]\n\n for example \n\n
    perl pipeline_trawler_02_no_orthologs.pl -motif /path/ip-test/ip-test.cluster -sequences /path/sequences/sample.fasta\n\n";
    
    exit(1);
}

if ($help){ _usage() }

#==============================================================================
# Directories handling

# if no directory provided => exit [must set up in trawler.pl]
unless($directory) {
    print STDERR "\nERROR: no directory to run\n";
    exit(1);
}
# extract tmp_xxx
my $tmp_dir_name = fileparse($directory);
# default result directory is like $TRAWLER_HOME/tmp_YYYY-MM-DD_HHhmm:ss/result
my $tmp_result_dir = File::Spec->catdir( $directory, $tcst{RES_DIR_NAME} );
my $tmp_fasta_dir = File::Spec->catdir( $tmp_result_dir, $tcst{FASTA_DIR_NAME} );
my $tmp_bed_dir = File::Spec->catdir( $tmp_result_dir, $tcst{BED_DIR_NAME});
my $tmp_features_dir = File::Spec->catdir( $tmp_result_dir, $tcst{FEATURES_DIR_NAME} );
my $phastcon_dir = File::Spec->catdir($tcst{GENOME}, $org, $tcst{PHSTCON_DIR_NAME});

#==============================================================================
# File handling

my $sorted_motifs = File::Spec->catfile($tmp_result_dir, $tcst{MOTIF_BED});
my $phastcon_scores = File::Spec->catfile($tmp_result_dir, $tcst{PHSTCN_FILE});

#==============================================================================

my $id2sequences = _parse_seq_file($file_sequences);

#==============================================================================

my $id2motif;

if ($file_motif) {
    $id2motif = _parse_cluster_file($file_motif);
}

#==============================================================================
# STAT file: $TRAWLWER_RESULT/features/STAT.tmp

my $temp_motif_bed = create_tmp_file( 'temp_motif_bed_XXXX', $tmp_result_dir, '.bed');
open (FHT, '>', $temp_motif_bed) or die "could not open temporary motif bed file\n";

my %FEATURES;
my %SCORES;

foreach my $id (keys %$id2sequences) {
    # fasta file: $TRAWLER_RESULT/fasta/<id>.fasta
    my $file = File::Spec->catfile($tmp_fasta_dir, $id . $tcst{FASTA_FILE_EXT});
    my @loc_array = split(/\-/, $id);
    open(OUT, ">$file") or croak "Cannot open file $file: $!";
    my $ref_seq = $$id2sequences{$id};
    print OUT ">$id\n$ref_seq\n";
    foreach my $idmotif (keys %$id2motif) {
        my @motifs = @{$$id2motif{$idmotif}};
        
        foreach my $motif (@motifs) {
            my ($mot, $mstarts, $mends, $strands) = get_motif_loc($ref_seq, $motif);
            if ($mot) {
                my $size_mot = @$mot;
                for (my $incr = 0; $incr<$size_mot; $incr++) {
                    my $m_start = $$mstarts[$incr];
                    my $m_end = $$mends[$incr];
                    my $m_strand = $$strands[$incr];
                    my $length_seq = length($$mot[$incr]);
                    
                    #get bed for motifs
                    my $b_start = $loc_array[1] + $m_start;
                    my $b_end = $b_start + $length_seq;
                    my $loci = $loc_array[0]."\t".$b_start."\t".$b_end."\t".$motif."\t".$m_strand;
                    print FHT $loci."\n";
                    
                    my $id = $loc_array[0]."_".$b_start."_".$b_end."_".$m_strand;
                    push @{$FEATURES{$idmotif}->{$id}->{$motif}->{"start"}}, $b_start;
                    push @{$FEATURES{$idmotif}->{$id}->{$motif}->{"end"}}, $b_end;
                    
                }
            }
        }
    }
    close(OUT) or croak "Can't close file '$file': $!";
}

system ("sort -k1,1 -k2,2n $temp_motif_bed |uniq -f1 > $sorted_motifs");

$phastcon_scores = get_conservation( $sorted_motifs, $directory, $phastcon_dir, $phastcon_scores );

open (PHSTCN_SC, $phastcon_scores) or die;

while (my $line = <PHSTCN_SC>){
    chomp ($line);
    my ($chr, $start, $end, $avg, $max) = split(/\t/, $line);
    $SCORES{$chr."_".$start."_".$end}=$avg."\t".$max;
}
####

#Generate STAT file
my $file_stat = File::Spec->catfile($tmp_features_dir, $tcst{STAT_FILE_NAME});
open (STAT_FILE, '>', $file_stat) or die;
print STAT_FILE "#id\tmotif_id\tmotif\tstart\taverage_conservation\tmax_conservation\tsequence_length\tstrand\tstart_from_end\n";

foreach my $idmotif ( keys %FEATURES ){
    foreach my $loc ( keys $FEATURES{$idmotif} ){
        foreach my $mot (keys  $FEATURES{$idmotif}{$loc} ){
            my ($chr, $start, $end, $strand) = split ('_', $loc);

            my $length = $end - $start;
            my $id = $chr."_".$start."_".$end;

            if ($SCORES{$id}){
                print STAT_FILE $id."\t".$idmotif."\t".$mot."\t".$start."\t".$SCORES{$id}."\t".$length."\t".$strand."\t".$end."\n";
            }else{#if phastcon score not available for bed region
                print STAT_FILE $loc."\t".$idmotif."\t".$mot."\t".$start."\t0\t0\t".$length."\t".$strand."\t".$end."\n";
            }
        }
    }
}

close(STAT_FILE) or croak "Can't close file '$file_stat': $!";

#==========================================================
#deal with features
#==========================================================

foreach my $file1 (keys %FEATURES) {
    my $tmp = $FEATURES{$file1};
    
    foreach my $file2 (keys %$tmp) {
        # feature file: $TRAWLER_RESULT/features/<file1>_<file2>.txt
        my $feature_file = File::Spec->catfile($tmp_fasta_dir, $file1 . "_" . $file2. ".txt");
        open(FEATURE, ">$feature_file") or croak "Cannot open file $feature_file: $!";
        print FEATURE "$file1\tff00ff\nmotif\t009ba5\n";
        
        foreach my $feature (keys %FEATURES) {
            my $id2motif = $FEATURES{$feature};
            
            foreach my $id (keys %$id2motif) {
                my $motif2loc = $$id2motif{$id};
                
                foreach my $motif (keys %$motif2loc) {
                    my @starts = @{$$motif2loc{$motif}->{"start"}};
                    my @ends = @{$$motif2loc{$motif}->{"end"}};
                    my $l = @starts;
                    
                    for (my $i=0; $i<$l; $i++) {
                        my $s = $starts[$i];
                        my $e = $ends[$i];
                        
                        if($id eq $file2 && $feature ne $file1) {
                            print FEATURE "$feature\t$id\t1\t$s\t$e\tmotif\n";
                        }
                        elsif ($feature eq $file1 && $id eq $file2) {#same family therefore same color
                            print FEATURE "$motif\t$id\t1\t$s\t$e\t$file1\n";
                        }
                    }
                }
            }
        }
        close(FEATURE) or croak "Can't close file '$feature_file': $!";
    }
}


#==============================================================================
#sub routines

#generate conservation scores from complete bedfile of motifs
sub get_conservation{
    my ($motif_bed_in, $tmp_dir, $input_dir, $phastcon_output) = @_;
    
    my $max_temp_output;
    my $mean_temp_output;
    
    #process phastcon files into hash
    my %phastcon_files;
    my %avgInput;
    
    opendir (DIR, $input_dir) or die "cannot read directory $phastcon_dir\n\n";
    
    while (my $file = readdir(DIR)){
        next if ($file !~ /.bw$/);
        my @file_array = split(/\./, $file);
        $phastcon_files{$file_array[0]}=$file;
    }
    
    closedir DIR;
    #=========================================================
    
    #create temp file
    my $temp_output = create_tmp_file( 'temp_output_XXXX', $tmp_bed_dir, '.bed');
    
    #sort motif bed into hash based on chromosome
    open(FHM, $motif_bed_in) or die;
    
    my $counter = 0;
    while (my $line = <FHM>){
        chomp($line);
        my($chr, $start, $end, $motif, $strand) = split (/\t/, $line);
        $avgInput{$chr}{$chr."_".$counter} = $start."\t".$end."\t".$chr."_".$start."_".$end."_".$motif."_".$strand;
        $counter++;
    }
    
    close(FHM);
    #=========================================================
    open (FHO, '>', $phastcon_output) or die; #final output

    if ( my $chr = keys %phastcon_files == 1 ){#if phastcon file saved as single file
        
        my $temp_input = create_tmp_file( 'temp_input_XXXX', $tmp_bed_dir, '.bed');
        
        open (TEMP, '>', $temp_input) or die;
        while ( my ($chr, $value) = each %avgInput ){
            while ( my ($region) = each $avgInput{$chr} ){

                print TEMP $chr."\t".$avgInput{$chr}{$region}."\n";#need 4th column as name
                
            }
        }

        print "extracting phastcon scores for ".$phastcon_files{$org}."\n";
        system("$tcst{BW_AVG} -minMax ".$input_dir."/".$phastcon_files{$org}." ".$temp_input." ".$temp_output);

        #process output file from bigWigAverageOverBed
        open (FHI, $temp_output) or die "could not open $temp_output";
        while (my $line = <FHI>) {
            chomp $line; #remove the end 'new line' symbol
            my @t=split('\s+',$line); #splits the line into separate strings
            my ($chr, $start, $end) = split('\_', $t[0]);
            if ((scalar(@t) < 8) || ($t[2] == 0)){
                $max_temp_output = "NA";
                $mean_temp_output = "NA";
            } else {
                $max_temp_output = $t[7];
                $mean_temp_output = $t[5];
            }
            
            print FHO "$chr\t$start\t$end\t$mean_temp_output\t$max_temp_output\n";
        }
    }else{#for phastcon files separated into files by chromosome
    
        foreach my $chr ( sort keys %avgInput ){ #create bed file and generate phastcon based on chr
            
            my $temp_input = create_tmp_file( $chr.'_XXXX', $tmp_bed_dir, '.bed');
            open (TEMP, '>', $temp_input) or die;
            foreach my $region ( keys %{ $avgInput{$chr} } ){
                
                print TEMP $chr."\t".$avgInput{$chr}{$region}."\n";#need 4th column as name
                
            }
            close TEMP;
            if ($phastcon_files{$chr}){
                print "extracting phastcon scores for $chr\n";
                system("$tcst{BW_AVG} -minMax ".$input_dir."/".$phastcon_files{$chr}." ".$temp_input." ".$temp_output);
                
                #process output file from bigWigAverageOverBed
                open (FHI, $temp_output) or die "could not open $temp_output";
                while (my $line = <FHI>) {
                    chomp $line; #remove the end 'new line' symbol
                    my @t=split('\s+',$line); #splits the line into separate strings
                    my ($chr, $start, $end) = split('\_', $t[0]);
                    if ((scalar(@t) < 8) || ($t[2] == 0)){
                        $max_temp_output = "NA";
                        $mean_temp_output = "NA";
                    } else {
                        $max_temp_output = $t[7];
                        $mean_temp_output = $t[5];
                    }
                    
                    print FHO "$chr\t$start\t$end\t$mean_temp_output\t$max_temp_output\n";
                }
            }
            close(FHI);
        }
    }
    close(FHO);
    return $phastcon_output;
}

sub reverse_complement {
    my ($patt) = @_;
    my @array = split //, $patt;
    my $size = @array;
    my @reverse;
    
    for (my $i=$size-1; $i>=0; $i--) {
        my $nt = $array[$i];
        my $comp_nt = complement($nt);
        push @reverse, $comp_nt;
    }
    my $result = join '', @reverse;
    return $result;
}

sub complement {
    my ($nt) = @_;
    
    my $result;
    
    if($nt eq "A") { $result = "T"; }
    elsif($nt eq "T") { $result = "A"; }
    elsif($nt eq "C") { $result = "G"; }
    elsif($nt eq "G") { $result = "C"; }
    elsif($nt eq "M") { $result = "K"; }
    elsif($nt eq "K") { $result = "M"; }
    elsif($nt eq "R") { $result = "Y"; }
    elsif($nt eq "Y") { $result = "R"; }
    elsif($nt eq "V") { $result = "B"; }
    elsif($nt eq "B") { $result = "V"; }
    elsif($nt eq "D") { $result = "H"; }
    elsif($nt eq "H") { $result = "D"; }
    elsif($nt eq "W") { $result = "W"; }
    elsif($nt eq "S") { $result = "S"; }
    elsif($nt eq ".") { $result = "."; }
    elsif($nt eq "N") { $result = "N"; }
    else { $result = "n"; }
    
    return $result;
}

#called by get_motif_position
sub get_motif_loc {
    my ($DNA, $motif) = @_;
    my $motif_rc = reverse_complement($motif);
    my $pattern_matching1 = _reg_exp($motif);
    my $pattern_matching2 = _reg_exp($motif_rc);
    #simply a pattern matching of the motif on the sequence
    my $matches = 0;
    my $motif_length = length($motif);
    my @motifs; my @start; my @end; my @strand;
    while ($DNA =~ m/($pattern_matching1)/g) { #the motif
        my $m = $1;
        my $motif_length = length($m);
        my $pos = pos $DNA;
        push @start, ($pos-$motif_length);
        push @end, $pos;
        push @motifs, $m;
        push @strand, "1";
    }
    while ($DNA =~ m/($pattern_matching2)/g) { #the reverse complement motif
        my $m = $1;
        my $motif_length = length($m);
        my $pos = pos $DNA;
        push @start, ($pos-$motif_length);
        push @end, $pos;
        push @motifs, $m;
        push @strand, "-1";
    }
    return (\@motifs, \@start, \@end, \@strand);
}

sub create_tmp_file {
    my ($file, $dir, $type) = @_;
    my $tmp_file = File::Temp->new( TEMPLATE => $file,
    DIR => $dir,
    SUFFIX => $type,
    );
    my $filename = $tmp_file->filename;
    return $filename;
}

sub _usage{
    print "############################################################################\n";
    print "# Error Message - Invalid Arguments\n";
    print "############################################################################\n";
    print "Please provide the following arguments in order:\n1 - the path and filename of bedfile \n(eg. /path/to/file/filename.bed ) \n\n";
    print "2 - the path for the output file (without / and the end) \n(eg. /path/to/outputfile/PhastCons_score.bed) \n\n";
    print "3 - the path for the bigWigAverageOverBed. You can download this from: http://hgdownload.cse.ucsc.edu/admin/exe/userApps.src.tgz \n(eg. /path/to/bigWigAverageOverBed)\n\n";
    print "4 - the path for the folder containing PhastCons score database from \n(eg. /Users/your_name/Downloads/placental) This folder should contain a list of compressed files in \".placental.pp.data.bw\" format, corresponding to each chromosome in mouse. \n\n";
    print "5 - human or mouse (all lowercase letters) \n\n";
    
    print "Please try again with correct input arguments\n\n";
    exit;
}
