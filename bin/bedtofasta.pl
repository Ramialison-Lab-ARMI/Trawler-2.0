#########################################################################
#ARMI Monash 15/12/2014                                                 #
#Louis Dang                                                             #
#script to be used for generating fasta files from bed file input       #
#Requires bed file, complete set of chromosome fasta sequence           #
#accepts bedfile with or without chr at the start                       #
#########################################################################
#! usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use File::Spec::Functions qw[catfile catdir];

# die "requires bed file and organism name input\n" if (@ARGV <= 1);

# Locate Trawler modules
use FindBin ();
use lib "$FindBin::RealBin/../modules";
my $script_name = $FindBin::RealScript;
print "\n## Running $script_name\n";

use Trawler::Constants 1.0 qw( _read_config _tcst);

# Read config file
_read_config($FindBin::RealBin);
my %tcst = _tcst();

###debugging variables
my $counter = 0;
my @timer;
$timer[0]=time;
my $help;

#create fasta output file, set bed file, set chromosome folder
my $bedfile = "$ARGV[0]";
my $org = "$ARGV[1]";
my $dir = File::Spec->catdir( $tcst{GENOME}, $org, $tcst{CHR_DIR_NAME});
my @name = split('/', $bedfile);
my $output = $name[$#name].".fa";
my $input_chrom;
my %chromosomes;
my $print_error="";

GetOptions(
	'help'     => \$help,
	'output:s' => \$output,
    'dir:s'    => \$dir,
);

if ($help) { bedtofasta_usage(); }

print "Converting $name[$#name] to fasta format\n";

#open output file to be written
open (OUTPUT, '>', $output) or die "could not open output file $output"; #opens file to be written

opendir (CHR, $dir) or die "can not open chromosome directory type '-help' for usage\n";

###load chromosomes into hash
while (my $chromefile = readdir(CHR)){
    next if ($chromefile !~ /.fa$/);
    my @c = split(/[.]/, $chromefile);
    $chromosomes{"chr".$c[$#c-1]}=$chromefile;
}

###load input bed file into hash
my %bed_hash;
open (BED, $bedfile) or die "could not open bed file $bedfile\n type '-help' for usage\n";
while (my $loci = <BED>){
    chomp $loci;
    my @split = split (/\t/, $loci);
    if ($split[0] =~ /^chr/){
        $bed_hash{$split[0]}{$counter}="$split[1]\t$split[2]";
    }else{
        $bed_hash{"chr".$split[0]}{$counter}="$split[1]\t$split[2]";
    }
    $counter ++;
}

###iterate through each chromosome of bed hash
foreach my $name (sort keys %bed_hash){
    ###open chromosome file for corresponding chromosome
    if ($chromosomes{$name}){
        my $input_chrom = $chromosomes{$name} or next;#"$name could not be found\n"
#        print $input_chrom."\n";
        open (CHROMO, $dir."/".$input_chrom) or die "$name is not a valid chromosome\n";
        chomp(my @array = <CHROMO>);
        close CHROMO;
        foreach my $region (keys %{ $bed_hash{$name} }){
            my @b = split('\t', $bed_hash{$name}{$region});
            #title for fasta seqeunce
            print OUTPUT ">".$name."-$b[0]-$b[1]\n";
            #setting variables for 'for' loop
            my $length = $b[1]-$b[0];   #length of loci/region
            my $base_length = length $array[1]; #bases per line in input fasta file
            my $startline = int($b[0]/$base_length); #starting line of interval in array
            my $startbase = $b[0] - $startline*$base_length; #start base postition
            my $endline = int($b[1]/$base_length); #ending line of interval in array
            my $endbase = $b[1] - $endline*$base_length;#end base postion
    
            #printing sequences into file
            #first line of fasta offset to consider bed region not starting at start of the line
            #iteratively prints subsequent lines within bed region
            #final line is printed as substring of endline with 0 offset and length based on endbase
            if ($length <= $base_length){
                print OUTPUT substr($array[$startline+1], $startbase-1, $length)."\n";
            }else{
                print OUTPUT substr($array[$startline+1], $startbase-1);
                for (my $i = int($b[0]/$base_length)+1; $i <= $startline + int($length/$base_length); $i++){
                    print OUTPUT $array[$i+1];
                }
                print OUTPUT substr($array[$endline+1], 0, $endbase)."\n";
            }
        }
    }else{
        $print_error.="chromosome ".$name." cannot be found\n";
    }
}

close OUTPUT;

$timer[1] = time;
my $run_time = $timer[1]-$timer[0];
print $print_error;
print "run time: $run_time\n";

sub bedtofasta_usage{
    
    print "\nScript to convert bed to fasta.\n";
    print "\n\tUsage: bedtofasta.pl [bed_filename] [organism] -output [output_filename]\n";
    print "\tAccepts organism as UCSC build number\n";
    print "\tOutput flename is optional\n";
    print "\tAll chromosomes in fasta format required for organism\n";
    print "\tChromosomes for each organism must be in separate folders\n";
    print "\t\ti.e: all mm9 chromosomes in one folder, all mm8 in another etc.\n\n";
    
    exit(1);
}