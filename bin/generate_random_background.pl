####################################################################################################
#### ARMI Monash University                                                                     ####
#### 10-12-2014                                                                                 ####
#### this program generates a random background from a sample distribution and an average length####
#### requires sample bedfile and organism name 													####
####################################################################################################
#!/usr/bin/perl

use List::Util qw(sum);
use strict;
use Getopt::Long;
use File::Spec::Functions qw[catfile catdir];

if (@ARGV<2) {
    die "argument requred"
}

# Locate Trawler modules
use FindBin ();
use lib "$FindBin::RealBin/../modules";
my $script_name = $FindBin::RealScript;
print "\n## Running $script_name\n";

use Trawler::Constants 1.0 qw( _read_config _tcst);

# Read config file
_read_config($FindBin::RealBin);
my %tcst = _tcst();

#####################
#load the parameters#
#####################
my $bedfile = $ARGV[0];
my @name = split ('/', $ARGV[0]);
my $output = $name[$#name]."_rand_bg.bed";
my $org = $ARGV[1];
my $dir = File::Spec->catdir( $tcst{GENOME}, $org);

GetOptions('output:s' => \$output);

###################################
#load chromosome lengths from file#
###################################
my $length_file = $dir."/".$org.".chrom.sizes.txt";

open (my $length_fh, $length_file) or die "could not open $length_file";

my %chromoLength;

while (my $line = <$length_fh>){
    chomp $line;
    my @hash = split('\t', $line);
    $chromoLength{"$hash[0]"} = $hash[1];
}

close $length_fh;

######################
#load genes into hash#
######################

my %EnsEMBLIDs;
my $totalGenes = 0;
my %gene;
my $ensgFile = $dir."/".$org."_genes.txt";
open (FIN, $ensgFile) || die "Can not open input file";#opens input file
while (my $line=<FIN>) {#####Ensembl Gene ID	Associated Gene Name	Chromosome Name	Gene Start (bp)	Gene End (bp)	Strand
    next if $line =~ /^Ensembl/;
    $totalGenes++;
    chomp $line;
    my @line_array = split ('\t', $line);
    ###$gene{chromosome}{ensembl-ID}="gene start    gene end    strand"
#     $gene{$line_array[2]}{$line_array[0]}=$line_array[3]."\t".$line_array[4]."\t".$line_array[5];###bed input without chr
    $gene{"chr".$line_array[2]}{$line_array[0]}=$line_array[3]."\t".$line_array[4]."\t".$line_array[5];###bed input with chr
    $EnsEMBLIDs{$totalGenes}=$line;
#     print "test\n";
}
close FIN;


#######################
#generate distribution#
#######################

my %distribution;
my @length_array;
my $temp;
my $counter = 0;

my @timer;
$timer[0] = time;

open (BED, $bedfile) or die "could not open input bedfile";
#my @arraybed = <BED>;
#close BED;

#while (my $loci = shift(@arraybed)){
while (my $loci = (<BED>)){
    
    ###set values to be used for comapring to gene loci
    my $distance = 300000000;###use large distance to start off search for smallest distance
    my @b = (split '\t',$loci);
    ###length array used for mean length
    $length_array[$counter]=$b[2]-$b[1];

    foreach my $subject (keys %{ $gene{$b[0]} }) {

        my @g = split('\t', $gene{$b[0]}{$subject});
        if ($g[2]==1){### check +/- strand
            $temp = $b[1] - $g[0];###caluclate distance between gene start site and bed region
            if ($temp < 0){###check if distance is negative (upstream)
                if (abs($temp) < abs ($distance)){###compare current value with new to see which is shorter
                    $distance = $temp;###update new value
                }
            ###otherwise temp>0 means downstream
            }elsif($temp < abs($distance)){
                $distance = $temp;
            }
            
        ###otherwise neg strand
        }else{
            $temp = $g[1] - $b[1];###caluclate distance between gene start site and bed region
            if ($temp < 0){###check if distance is negative (upstream)
                if (abs($temp) < abs ($distance)){###compare current value with new to see which is shorter
                    $distance = $temp;### update new value
                }
            ###otherwise temp>0 means downstream
            }elsif($temp < abs($distance)){###update with new value if it is closer than the old
                $distance = $temp;
            }
        }
    }
    
    $counter ++;
    ###sorting distance into discrete distances from gene start site
    ###negative value represents upstream region of start site
    if ($distance < -50000){
        $distribution{"-5000000_-49999"}++;
    }elsif($distance >= -50000 && $distance < -5000){
        $distribution{"-49999_-4999"}++;
    }elsif($distance >= -5000 && $distance < 0){
        $distribution{"-4999_0"}++;
    }elsif($distance >= 0 && $distance < 5000){
        $distribution{"0_4999"}++;
    }elsif($distance >= 5000 && $distance < 50000){
        $distribution{"4999_49999"}++;
    }elsif($distance >= 50000 && $distance <=500000){
        $distribution{"49999_5000000"}++;
    }
}
close BED;
my $mean_length = int(mean(@length_array));###generate mean length
print "mean length:".	$mean_length."\n";

$timer[1]=time;
my $run_time = $timer[1]-$timer[0];

print "Distribution:\n";
print "$_ $distribution{$_}\n" for ( sort {$a <=> $b} keys %distribution);


#####################
#get random background
#####################

open (OUTPUT, '>', $output) or die "could not open $output";

for (my $i=0;$i<10;$i++){#####how many times you want the background to be bigger
#for (my $i=0;$i<100;$i++){#####how many times you want the background to be bigger
    foreach my $interval(keys %distribution){
    	my $orientation;
        my @i=split/_/,$interval;
        my $minInt=$i[0];
        my $maxInt=$i[1];
        my $range=$maxInt-$minInt;
        ###condition for upstream or downstream
        if ($minInt=$i[0] < 0){
            $orientation = "upstream";
        }elsif($minInt=$i[0] >=0){
            $orientation = "downstream";
        }
        my $seqnum2fetch=$distribution{$interval};
        for (my $j=0;$j<$seqnum2fetch;$j++){#####how many sequences were present in that interval
            my $randPos=int(rand($range))+$minInt;
            my $random_gene_upstream=int(rand($totalGenes));
            my $interval_upstream=getInterval($random_gene_upstream,$randPos,$orientation,$mean_length);
            print OUTPUT $interval_upstream."\n";
        }
    }
}

close OUTPUT;

################
#Sub routines  #
################
sub getInterval{
    my ($gene,$start,$orient,$mean_length)=@_;
    my $ensInfo=$EnsEMBLIDs{$gene};
    my @e=split/\t/,$ensInfo;
    my $chr="chr".$e[2];
    my $chrStart=$e[3];
    my $chrEnd=$e[4];
    my $chrStrand=$e[5];
    my $full_length=int(rand($mean_length))+int($mean_length/2);
    my $half_length=int($full_length/2);
#    print $ensInfo."\t".$start."\t".$orient."\t".$full_length."\n";
    my $bed_start;
    my $bed_end;
    if ($chrStrand==-1){
        if ($orient eq "upstream"){
            $bed_start=$chrEnd+$start-$half_length;
            $bed_end=$chrEnd+$start+$half_length;
        }
        if ($orient eq "downstream"){
            $bed_start=$chrEnd-$start-$half_length;
            $bed_end=$chrEnd-$start+$half_length;
        }
    }
    if ($chrStrand==1){
        if ($orient eq "upstream"){
            $bed_start=$chrStart-$start-$half_length;
            $bed_end=$chrStart-$start+$half_length;
        }
        if ($orient eq "downstream"){
            $bed_start=$chrStart+$start-$half_length;
            $bed_end=$chrStart+$start+$half_length;
        }
    }
    #check to see if bed regions are within range of chromosome length
    if ($bed_start<0){$bed_start=0;}
    if ($bed_start>$chromoLength{$chr}){$bed_start=$chromoLength{$chr}-$full_length;}
    if ($bed_end>$chromoLength{$chr}){$bed_end=$chromoLength{$chr};}
    if ($bed_end<0){$bed_end=$bed_start+$full_length;}
    my $intervalsize=$bed_end-$bed_start;
#     print $intervalsize."\t";
    my $bed_interval=$chr."\t".$bed_start."\t".$bed_end;
    return $bed_interval;
}

###sub routine to calculate average length of bed regions
sub mean {
    return sum(@_)/@_;
}


