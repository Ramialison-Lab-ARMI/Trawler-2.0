#!/usr/bin/perl

# $Id: pipeline_trawler_03.pl,v 1.32 2009/05/05 15:01:04 ramialis Exp $

=pod

=head1 NAME

  pipeline_trawler_03.pl

=head1 SYNOPSIS

    pipeline_trawler_03.pl -directory runName -conservation 1/0

=head1 DESCRIPTION

  A script which parses the output files from pipeline_trawler_01.pl and pipeline_trawler_02.pl for a given run:
    1- runName.cluster (list of over-represented instances and SD)
    2- features/STAT.tmp (conservation count)
    3- runName_compare.txt (TFBS database hits)
    The output is an html file.

=head1 OPTIONS

    -directory #name of the run

=head1 CONTACT

  EMBL 2008
  Mirana Ramialison ramialis@embl.de
  Yannick Haudry haudry@embl.de

=cut

#==============================================================================
# Read and Set properties
#==============================================================================

use strict;
use Carp;
use File::Basename;
use Getopt::Long;
use CGI;
use CGI qw(:standard :html3 *table);
use File::Spec;

# Locate Trawler modules
use FindBin ();
use lib "$FindBin::RealBin/../modules";
my $script_name = $FindBin::RealScript;

# Trawler Modules
use Trawler::Constants 1.0 qw(_read_config _tcst);

# START processing
print "\n## Running $script_name\n";

###############################################################################

use constant HTML_INDEX  =>  'index.html';

use constant CLASS_TAB  =>  'tab_panel';
use constant CLASS_SORTER  =>  'tablesorter';
use constant CLASS_TOOLTIP  =>  'tooltip';

use constant LINK_TRAWLER => 'https://trawler.erc.monash.edu.au';

use constant MAILTO_BENEDICT => 'mailto:benedict@soe.ucsc.edu';
use constant MAILTO_MIRANA => 'mailto:mirana.ramialison@monash.edu';
use constant MAILTO_YANNICK => 'mailto:haudry@embl.de';

###############################################################################

#==============================================================================
# Read and Set properties
#==============================================================================

# Read config file
_read_config($FindBin::RealBin);
my %tcst = _tcst();

# Logging Levels
my $DEBUG = $tcst{DEBUG};
my $INFO  = $tcst{INFO};

#############################################################
# Set parameters                                            #
#############################################################
#global parameters, to uncheck when used done

#PATH
my $RES_PATH = $tcst{RES_PATH};

#==============================================================================

my $directory = undef;
my $conservation = undef;
my $org = undef;
GetOptions(
  'directory=s'    => \$directory,
  'conservation=s' => \$conservation,
  'org:s'    => \$org,
);

# are we in conservation mode ?
if ($conservation) {
  print "HTML ouput with conservation\n" if $DEBUG;
}

# if no directory provided => exit
unless($directory) {
    print STDERR "\nERROR: no directory to run\n";
    exit(1);
}

# TRAWLER VERSION
my $version = $tcst{trawler_version};

# FIXME[YH]: naming conventions..
my ($RES_DIR_NAME, $RES_DIR_PATH) = fileparse($directory);
my $WORKING_DIR = File::Spec->catdir( $directory, $tcst{RES_DIR_NAME} );
my $session_id = basename($directory);

my $COMPARE_FILE_NAME = File::Spec->catfile($WORKING_DIR, $RES_DIR_NAME . "_compare.txt");
my $STAT_FILE_NAME = File::Spec->catfile(($WORKING_DIR, "features"), $tcst{STAT_FILE_NAME} );
my $CLUSTER_FILE_NAME = File::Spec->catfile($WORKING_DIR, $RES_DIR_NAME . $tcst{CULSTER_FILE_EXT} );
my $PWM_FILE = File::Spec->catfile($WORKING_DIR, $RES_DIR_NAME . $tcst{PWM_FILE_EXT} );
my $HTML_INDEX = File::Spec->catfile($directory, HTML_INDEX);


#### Downloadable files [not system dependent !!!, hence do not use cat() function]
my $input_link_dir = $tcst{INPUT_DIR_NAME} . "/";
my $result_link_dir = $tcst{RES_DIR_NAME} . "/";

my $input_file_link = $input_link_dir . $tcst{INPUT_FILE};
my $readme_file_link = $input_link_dir . $tcst{README_FILE};
my $license_file_link = $input_link_dir . $tcst{LICENSE_FILE};
my $trawler_raw_file_link = $result_link_dir . $RES_DIR_NAME . $tcst{TRAWLER_FILE_EXT};
my $trawler_sorted_file_link = $result_link_dir . $RES_DIR_NAME . $tcst{TRAWLER_SHORT_FILE_EXT};
my $cluster_file_link = $result_link_dir . $RES_DIR_NAME . $tcst{CULSTER_FILE_EXT};
my $pwm_file_link = $result_link_dir . $RES_DIR_NAME . $tcst{PWM_FILE_EXT};
####

my $html_download_dir = File::Spec->catdir( $directory, $tcst{HTML_DOWNLOAD} );
my $html_input_dir = File::Spec->catdir( $directory, $tcst{HTML_INPUT} );

my $sample_file = $tcst{HTML_DOWNLOAD} . "/sample.fa";
my $background_file = $tcst{HTML_DOWNLOAD} . "/rand_bg.fa";
my $zip = $tcst{HTML_DOWNLOAD}.'/'.$session_id.'.zip';

if ($DEBUG) {
    print "abs path[RES_DIR_PATH]: $RES_DIR_PATH \n";
    print "dir name[RES_DIR_NAME]: $RES_DIR_NAME \n";
    print "working directory[WORKING_DIR]: $WORKING_DIR \n";
    print "cluster file path[CLUSTER_FILE_NAME]: $CLUSTER_FILE_NAME \n";
    print "compare file path[COMPARE_FILE_NAME]: $COMPARE_FILE_NAME \n";
    print "stat file path[STAT_FILE_NAME]: $STAT_FILE_NAME \n";
    print "pwm file [PWM_FILE]: $PWM_FILE \n";
    print "result path $RES_PATH \n";
}

#############################################################
# HTML / JavaScript                                         #
#############################################################

# NOTES
# - external links configuration: rel="external"

# declare scripts, styles
# init Tabs
sub printHTMLhead() {
 return <<Head;
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="de scription" content="">
    <meta name="author" content="">
    <link rel="icon" href="bs/favicon.ico">

    <title>Trawler: Results</title>

    <link href="bs/bootstrap.min.css" rel="stylesheet">
    <link href="bs/jumbotron.css" rel="stylesheet">
    
    <script src="bs/jquery.min.js"></script>
    <script src="bs/bootstrap.min.js"></script>
    <script src="bs/jquery.dataTables.min.js"></script>
    <script src="bs/dataTables.bootstrap.min.js"></script>
    
    <script src="bs/jquery.flot.min.js"></script>
    <script src="bs/jquery.flot.axislabels.js"></script>

    <script>

      \$(document).ready(function() {
        \$('#idx').DataTable( {
          "paging":   false,
          "searching": false,
          "info": false,
          "order": [[ 3, "desc" ]]
        })
      })

    </script>


  </head>

  <body>

    <nav class="navbar navbar-inverse navbar-fixed-top">
      <div class="container">
        <div class="navbar-header">
          <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target="#navbar" aria-expanded="false" aria-controls="navbar">
            <span class="sr-only">Toggle navigation</span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a  href="https://twitter.com/ramialison_lab" target="blank">
          <img class="navbar-brand" src="bs/zfish_og.png" alt="zebrafish_logo" width="80" height="100" align="left" href="https://twitter.com/ramialison_lab" target="blank"></a>
          <a class="navbar-brand" href="http://trawler.erc.monash.edu.au/">Trawler</a>

        </div>
        <div id="navbar" class="collapse navbar-collapse">
          <ul class="nav navbar-nav">
            <li><a href="http://trawler.erc.monash.edu.au/">Home</a></li>
            <li><a href="http://trawler.erc.monash.edu.au/help/">Help</a></li>
            <li class="active"><a href="index.html">Results</a></li>
          </ul>
         <img src="bs/logoARMI-MONASH.png" alt="zebrafish_logo" width="184" height="32" vspace="8" align="right"  usemap="#bannermap">
         <map name="bannermap">
          <area shape="rect" coords="0,0,100,32" alt="Monash" href="http://www.monash.edu/" target="blank">
          <area shape="rect" coords="110,0,184,32" alt="ARMI" href="http://www.armi.org.au/" target="blank">
        </map>
        </div><!--/.nav-collapse -->

      </div>
    </nav>

    </br>
    <div class="container">
    
      <div class="panel panel-default">
        <div class="panel-heading">

Head
}

#############################################################
# Run Main                                                  #
#############################################################
msg_pipeline(); # console output

#load cluster
print "Loading Cluster\n" if $DEBUG;
my %cluster = loadFileToHash($CLUSTER_FILE_NAME);
print "Cluster loaded from $CLUSTER_FILE_NAME\n" if $INFO;

#load compare
print "Loading Compare\n" if $DEBUG;
my %compare = loadFileToHash($COMPARE_FILE_NAME);
print "Compare loaded from $COMPARE_FILE_NAME\n" if $INFO;

#load stat
print "Loading Stat\n" if $DEBUG;
my %stat = loadFileToHash($STAT_FILE_NAME);

#load stat data for graphic display
my @stat_data = parse_stat($STAT_FILE_NAME);

print "Stat loaded from $STAT_FILE_NAME\n" if $INFO;

#create main list hash
my %families;
my %families_instances;
foreach my $h (keys %cluster){
  if ($h>0) { #avoids first line
    my @line=@{$cluster{$h}};
    my $fname=$line[1];
    my $new_SD = $line[2];
    $families_instances{$fname."_".$line[0]}=$new_SD;
    my $old_SD=0;
    if (exists $families{$fname}) { #gets old SD for this family
      $old_SD=$families{$fname};
    }
    if ($new_SD>$old_SD){ #check whether best SD
      $families{$fname}=$new_SD;
    }
  }
}

my %main_list;
my $tab_count = 1; # 2 is the Result tab [input | download | results | famailies...]
foreach my $family(keys %families) {
  $tab_count++;

  # relative link to image directory
  my $image = File::Spec->catfile($tcst{HTML_IMG}, $family . $tcst{MOTIF_PNG_EXT});

  # tab link (image column)
  my $image_scr = a( { href => '#', onclick => "\$('[href=\"#".$family."\"]').tab('show');" },
                       img( { -src => $image, -class => 'small', -alt=>$image } ) );

  # tab link (family column) $('.nav-tabs a[href='+hash+']').tab('show');
  my $html_link = a( { href => '#', onclick => "\$('[href=\"#".$family."\"]').tab('show');"}, $family );

  #extract compare Table1
  my $compare_list;
  my $compare_family;
  $compare_family = start_table( { class => 'table table-striped table-hover table-bordered HATFD', id => $family."Tf" } );
# foreach my $hits_num_comp (sort keys %compare){
#        if ($compare{$hits_num_comp}[0] eq 'Query_ID'){ #headline
#            $compare_family.=Tr(th([
#                                    @{$compare{$hits_num_comp}}
#                                    ]));
#        }
#        if ($compare{$hits_num_comp}[0] eq $family){
#            $compare_family.=Tr(td([@{$compare{$hits_num_comp}}]));
#            if (length($compare{$hits_num_comp}[2])>0){
#                $compare_list.=$compare{$hits_num_comp}[2].";";
#            }
#        }
#    }
  my $compare_family_thead;
  my $compare_family_tbody;
  my $Query_ID="Name of the input family matrix (query)";
  my $Query_Consensus="Consensus of the query matrix";
  my $Subject_Name="Name of the hit matrix with divergence smaller than the given cutoff (subject)";
  my $Source_DB="Source database of the subject matrix";
  my $Subject_ID="Database ID of the subject matrix";
  my $Length="Length of the consensus sequence of the subject matrix";
  my $Orientation="Orientation between query and subject matrices ";
  my $Offset="Shift between query and subject matrices";
  my $Divergence="Dissimilarity score between query and subject matrices";
  my $Overlap="Overlap between query and subject matrices";
  my $Subject_Consensus="Consensus sequence of the subject matrix";

  foreach my $hits_num_comp (sort keys %compare){
      # headline
    if ($compare{$hits_num_comp}[0] eq 'Query_ID'){
      #$compare_family_thead .= Tr( th( [ @{$compare{$hits_num_comp}} ] ) );
      $compare_family_thead .= Tr( th( [
        div( { title => $Query_ID }, $compare{$hits_num_comp}[0]),
        div( { title => $Query_Consensus }, $compare{$hits_num_comp}[1]),
        div( { title => $Subject_Name }, $compare{$hits_num_comp}[2]),
        div( { title => $Source_DB }, $compare{$hits_num_comp}[3]),
        div( { title => $Subject_ID }, $compare{$hits_num_comp}[4]),
        div( { title => $Length }, $compare{$hits_num_comp}[5]),
        div( { title => $Orientation }, $compare{$hits_num_comp}[6]),
        div( { title => $Offset }, $compare{$hits_num_comp}[7]),
        div( { title => $Divergence }, $compare{$hits_num_comp}[8]),
        div( { title => $Overlap }, $compare{$hits_num_comp}[9]),
        div( { title => $Subject_Consensus }, $compare{$hits_num_comp}[10]),
                   ] ) );
    }
    # tbody TF db
    if ($compare{$hits_num_comp}[0] eq $family) {
          # Add HOCOMOCO / JASPAR /UniPROBE links
          if ($compare{$hits_num_comp}[3] eq 'JASPAR') {
              my $id = $compare{$hits_num_comp}[4];
              $compare{$hits_num_comp}[3] = a( {
                  href => "http://jaspar.genereg.net/cgi-bin/jaspar_db.pl?ID=".$id."&rm=present&collection=CORE",
                  title => "JASPAR:".$id,
                  rel => "external" },
              'JASPAR' );
          } elsif ($compare{$hits_num_comp}[3] eq 'HOCOMOCO') {
              my $id = $compare{$hits_num_comp}[4];
              $compare{$hits_num_comp}[3] = a( {
                  href => "http://hocomoco.autosome.ru/motif/".$id,
                  title => "HOCOMOCO:".$id,
                  rel => "external" },
              'HOCOMOCO' );
          } elsif ($compare{$hits_num_comp}[3] eq 'UniPROBE') {
              my $id = $compare{$hits_num_comp}[4];
              $compare{$hits_num_comp}[3] = a( {
                  href => "http://the_brain.bwh.harvard.edu/uniprobe/detailsDef.php?id=".$id,
                  title => "UniPROBE:".$id,
                  rel => "external" },
              'UniPROBE' );
          }
        # Create table rows
      $compare_family_tbody .= Tr( td( [ @{$compare{$hits_num_comp}} ] ) );
      if (length($compare{$hits_num_comp}[2])>0){
        $compare_list .= $compare{$hits_num_comp}[2].", ";
      }
    }
  } # end build TF db Table
  #print "****THEAD\n";
  #print $compare_family_thead."\n";
  #print "****TBODY\n";
  #print $compare_family_tbody."\n";

  $compare_family .= thead( $compare_family_thead );
  $compare_family .= tbody( $compare_family_tbody );
  $compare_family .= end_table();

  #extract sequences
  my %unique_positions;
  my %family_bestCS;
  foreach my $hits_num_seq (sort keys %stat) {
    if ($stat{$hits_num_seq}[1] eq $family) { # treats one family at a time
      #gets family best CS
      my $new_CS = $stat{$hits_num_seq}[5];
      my $old_CS = -1;
      if (exists $family_bestCS{$family}) { #gets old_CS for this family
         $old_CS = $family_bestCS{$family};
      }
      if ($new_CS>$old_CS) { #check whether $new_CS
         $family_bestCS{$family} = $new_CS;
      }

      #checks if same position
      my $instance_position = $stat{$hits_num_seq}[0]."_".$stat{$hits_num_seq}[3];
      # FIXME[YH]: use href as id
      #my $jalview_link = createJalview($stat{$hits_num_seq}[0], $family.'_'.$stat{$hits_num_seq}[0]);
      my $jalview_link = $stat{$hits_num_seq}[0]; # seq_name

      if (exists $unique_positions{$instance_position}) {

        my $bestCS_at_this_position = $unique_positions{$instance_position}[4];
        my $instance_with_bestCS_at_this_position = $unique_positions{$instance_position}[5];
        if ($stat{$hits_num_seq}[5] > $unique_positions{$instance_position}[4]) { #best CS
          $bestCS_at_this_position = $stat{$hits_num_seq}[5];
          $instance_with_bestCS_at_this_position = $stat{$hits_num_seq}[2];
       }

        my $bestSD_at_this_position=$unique_positions{$instance_position}[5];
        my $instance_with_bestSD_at_this_position = $unique_positions{$instance_position}[6];
        if ($families_instances{$family."_".$stat{$hits_num_seq}[2]} > $unique_positions{$instance_position}[5]) { #best SD
          $bestSD_at_this_position = $families_instances{$family."_".$stat{$hits_num_seq}[2]};
          $instance_with_bestSD_at_this_position = $stat{$hits_num_seq}[2];
        }

        if ($conservation) {
    my ($chr, $start, $end) = split (/\-/, $stat{$hits_num_seq}[0]);
    my $m_start = $start + $stat{$hits_num_seq}[3];
    my $m_end = $end - $stat{$hits_num_seq}[8];
    
    my $chrTitle = $stat{$hits_num_seq}[0];
    $chrTitle =~ s/\-/\:/;

    @{$unique_positions{$instance_position}} = ( a( { -href => 'http://genome.ucsc.edu/cgi-bin/hgTracks?db='.$org.'&position='.$chr.'%3A'.$stat{$hits_num_seq}[9].'-'.$stat{$hits_num_seq}[10], -title => 'Display in UCSC', -target => 'blank' }, $chrTitle ),
                                                       $stat{$hits_num_seq}[3],
                                                       $stat{$hits_num_seq}[8], # start position from end
                                                       $stat{$hits_num_seq}[4],
                                                       $bestCS_at_this_position,
                                                       $instance_with_bestCS_at_this_position,
                                                       $bestSD_at_this_position,
                                                       $instance_with_bestSD_at_this_position,
                                                       $stat{$hits_num_seq}[7]); # strand
        }
        else {
          @{$unique_positions{$instance_position}} = ( $stat{$hits_num_seq}[0],
                                                       $stat{$hits_num_seq}[3],
                                                       $stat{$hits_num_seq}[8], # start position from end
                                                       $bestSD_at_this_position,
                                                       $instance_with_bestSD_at_this_position,
                                                       $stat{$hits_num_seq}[7]); # strand

        }

      # if ($stat{$hits_num_seq}[4]>$unique_positions{$instance_position}[2]){ #best CS
      # @{$unique_positions{$instance_position}}=(a({-href=>$jalview_link},$stat{$hits_num_seq}[0]),$stat{$hits_num_seq}[3],$stat{$hits_num_seq}[4],$stat{$hits_num_seq}[5],$stat{$hits_num_seq}[2],$unique_positions{$instance_position}[4],$unique_positions{$instance_position}[5]);
      # }
      # if ($families_instances{$family."_".$stat{$hits_num_seq}[2]}>$unique_positions{$instance_position}[5]){ #best SD
      # @{$unique_positions{$instance_position}}=(a({-href=>$jalview_link},$stat{$hits_num_seq}[0]),$stat{$hits_num_seq}[3],$stat{$hits_num_seq}[4],$stat{$hits_num_seq}[5],$stat{$hits_num_seq}[2],$families_instances{$family."_".$stat{$hits_num_seq}[2]},$stat{$hits_num_seq}[2]);
      # }

      }
      else { #new position
         if ($conservation) {
    my ($chr, $start, $end) = split (/\-/, $stat{$hits_num_seq}[0]);
    my $m_start = $start + $stat{$hits_num_seq}[3];
    my $m_end = $end - $stat{$hits_num_seq}[8];

    my $chrTitle = $stat{$hits_num_seq}[0];
    $chrTitle =~ s/\-/\:/;

    @{$unique_positions{$instance_position}} = ( a( { -href => 'http://genome.ucsc.edu/cgi-bin/hgTracks?db='.$org.'&position='.$chr.'%3A'.$stat{$hits_num_seq}[9].'-'.$stat{$hits_num_seq}[10], title => 'Display in UCSC', target => 'blank'}, $chrTitle ),
                #@{$unique_positions{$instance_position}} = ( a( { -href=>"#",title=>$jalview_link }, $stat{$hits_num_seq}[0] ),
                                                        $stat{$hits_num_seq}[3],
                                                        $stat{$hits_num_seq}[8], # start from end
                                                        $stat{$hits_num_seq}[4],
                                                        $stat{$hits_num_seq}[5],
                                                        $stat{$hits_num_seq}[2],
                                                        $families_instances{$family."_".$stat{$hits_num_seq}[2]},
                                                        $stat{$hits_num_seq}[2],
                                                        $stat{$hits_num_seq}[7]); # strand

         }
         else {
           @{$unique_positions{$instance_position}} = ( $stat{$hits_num_seq}[0],
                                                        $stat{$hits_num_seq}[3],
                                                        $stat{$hits_num_seq}[8], # start position from end
                                                        $families_instances{$family."_".$stat{$hits_num_seq}[2]},
                                                        $stat{$hits_num_seq}[2],
                                                        $stat{$hits_num_seq}[7]); # strand


         }
      }
    }
  }
  my $seq_family = start_table( { class => 'table table-striped table-hover table-bordered HATFD', id => $family."Occ" } );
  # Tooltip text (on table header)
  my $seq_txt='Click on the sequence name to view the motif in UCSC';
  my $sta_txt='Start position of the motif within the sequence (from start)';
  my $end_txt='Start position of the motif within the sequence (from end)';
  my $avc_txt='Average conservation of the whole sequence';
  my $bcs_txt='Best conservation score of the motif within this sequence';
  my $ibc_txt='Consensus sequence of the instance of the motif with best conservation score';
  my $bzs_txt='Best Z-score of the motif within this sequence';
  my $ibz_txt='Consensus sequence of the instance of the motif with best Z-score';
  my $strand_txt='Strand: 1=forward, -1=reverse';
  if ($conservation) { # with alignments
    $seq_family.= thead( Tr( th [
            #'Sequence', 'Start_position (from start)', 'Start_position (from end)', 'Average_conservation',
            #'Best_conservation_score', 'Instance_with_best_CS', 'Best_Z-score', 'Instance_with_best_ZS'
            div( { title => $seq_txt }, "Sequence"),
            div( { title => $sta_txt }, "Start_position (from start)"),
            div( { title => $end_txt }, "Start_position (from end)"),
            div( { title => $avc_txt }, "Average conservation"),
            div( { title => $bcs_txt }, "Best conservation score"),
            div( { title => $ibc_txt }, "Instance_with_best_CS"),
            div( { title => $bzs_txt }, "Best_Z-score"),
            div( { title => $ibz_txt }, "Instance_with_best_ZS"),
            div( { title => $strand_txt }, "Strand")
            ]
          ) );
  }
  else { # without alignments
    $seq_family.= thead( Tr( th [
            #'Sequence', 'Start_position (from start)', 'Start_position (from end)',
            #'Best_Z-score', 'Instance_with_best_ZS'
            div( { title => $seq_txt }, "Sequence"),
            div( { title => $sta_txt }, "Start_position (from start)"),
            div( { title => $end_txt }, "Start_position (from end)"),
            div( { title => $bzs_txt }, "Best_Z-score"),
            div( { title => $ibz_txt }, "Instance_with_best_ZS"),
            div( { title => $strand_txt }, "Strand")
            ]
          ) );
  }

  my $seq_family_tbody;
  for my $kf (keys %unique_positions) {
      $seq_family_tbody .= Tr( td( [ @{$unique_positions{$kf}} ] ) );
  }
  $seq_family .= tbody( $seq_family_tbody );
  $seq_family .= end_table();

  createFamilyHTML($family, $compare_family, $seq_family);
  #populate the main list
  # FIXME[YH]: tablink
    #push( @{$main_list{$family}},a({href=>$html_link},$family));
    push( @{$main_list{$family}}, $html_link );
    push( @{$main_list{$family}}, $image_scr );
    push( @{$main_list{$family}}, $compare_list );
    push( @{$main_list{$family}}, $families{$family} );
    if ($conservation) {
       push( @{$main_list{$family}}, $family_bestCS{$family});
    }
}
print "Main list loaded\n" if $DEBUG;

################################################################################
# Create HTML index

open(FINDEX, '>'.$HTML_INDEX) or croak "Can not create index.html file ($HTML_INDEX): $!";
print FINDEX printHTMLhead(); # header and scripts
#### --- HTML header
=pod
print FINDEX "<div id=\"tr-siteContain\">";
print FINDEX "<div id=\"tr-header\">";
print FINDEX div( {id=>'tr-helpNav'},
             ul(
             li( a( { href => '#', onclick => 'showDiv(\'h_links\');' }, "Links"), ' | ' ),
             li( a( { href => '#', onclick => 'showDiv(\'h_readme\');' }, "Readme"), ' | ' ),
             li( a( { href => '#', onclick => 'showDiv(\'h_license\');' }, "License"), ' | ' ),
             li( a( { href => '#', onclick => 'showDiv(\'h_contact\');' }, "Contact") ),
             ) );
print FINDEX "</div>"; # tr-header
# TITLE
print FINDEX h1( a( { href => "/index.html", style => "color:#6c2d7b" },"Trawler"));
print FINDEX div( h2("Over-represented motifs discovery results") );
# HELP containers: links
print FINDEX div( { id => 'h_links', class => 'help hide-first' },
                  a( { href => '#', class => 'delete' }, "Hide" ),
                  a( { href => LINK_TRAWLER, rel => 'external' }, "Trawler Home Page"), br(),
                  );
print FINDEX div( { id=>'h_contact', class=>'help hide-first' },
                  a( { href => '#', class=>'delete' }, "Hide"),
                  "Contacts: ", br(),
                  a( { href => MAILTO_BENEDICT }, "Benedict Paten"), br(),
                  a( { href => MAILTO_MIRANA }, "Mirana Ramialison"), br(),
                  a( { href => MAILTO_YANNICK }, "Yannick Haudry"), br()
                );
print FINDEX div( { id=>'h_license', class => 'help hide-first' },
                  a( { href => $license_file_link,
                       rel => 'external',
                       onmouseover => "showfile('$license_file_link', 'lfile');" },
                       "LICENSE" ),
                  a( { href => '#', class => 'delete'}, "Hide" ),
                  pre( { id => 'lfile' } )
                );
print FINDEX div( { id=>'h_readme', class=>'help hide-first' },
                  a( { href => $readme_file_link,
                       rel => 'external',
                       onmouseover => "showfile('$readme_file_link', 'rfile');" },
                       "README" ),
                  a( { href => '#', class => 'delete'}, "Hide" ),
                  pre( { id => 'rfile' } )
                );

####
print FINDEX "<div id=\"container\">";

=cut

#### --- tabbed menu ---
my $family_tab_index;
foreach my $family(keys %families) {
  #$family_tab_index .= li( a( { href => $family.".html", title => $family.'_tab' }, span($family) ) );
  $family_tab_index .= li( a( { 'data-toggle' => "tab", href => "#".$family }, span($family) ) );
}
print FINDEX ul( { class => "nav nav-pills", role => "tablist" },
               li( a( { 'data-toggle' => "tab", href => '#udownload' }, span('Download') ) ),
               li( { class => "active" }, a( { 'data-toggle' => "tab", href => '#trmain' }, span('Results') ) ),
               $family_tab_index
);
print FINDEX "</div>";
print FINDEX "<div class=\"panel-body\"><div class=\"tab-content\">";


=pod
#### --- Input tab ---
my $input_tab = div( { id => 'uinput', class => CLASS_TAB },
                b("Input:"), br(),
                ul(
                  li( a( { href => $input_file_link,
                           rel => 'external',
                           onmouseover => "showfile('$input_file_link', 'ifile');"},
                           "Trawler options")
                     ) # li input file
                  ), # ul
                  # div container input file
                  div( { class=>'pane hide-first' },
                          a( { href=>'#', class=>'delete'}, "Hide" ),
                          pre( {id=>'ifile'} )
                     )
                ); # uinput div
$input_tab .= input_file_script();
# print input tab
print FINDEX $input_tab;
=cut

#### --- Download tab ---

#Legend: Trawler raw data and trawler sorted
my $legend_trawler = "Motif occurrence in the sample, Motif occurrence in the background, Z score, Motif";
#Legend: Clustered motif
my $legend_cluster = "Motif, Family name, Z score, Occurrence in the sample, Occurrence in the background, Strand";

my $download_tab = div( { id => 'udownload', class => "tab-pane fade" },
                   "Hover over download links for column descriptions</br></br>",
                   ul( # downloadable files
                    li( a( { href => $input_file_link,
                           rel => 'external', -target => 'blank'},
                           "Trawler input options")
                     ), # li input file
                     li( a( { href => $trawler_raw_file_link,
                             rel => 'external', -target => 'blank',
                              title => $legend_trawler },
                              "Trawler raw data" ) ),
                     li( a( { href => $trawler_sorted_file_link,
                             rel => 'external', -target => 'blank',
                              title => $legend_trawler },
                              "Trawler sorted data" ) ),
                     li( a( { href => $cluster_file_link,
                             rel => 'external', -target => 'blank',
                              title => $legend_cluster },
                              "Clustered motifs" ) ),
                     li( a( { href => $pwm_file_link, rel => 'external', -target => 'blank' }, "PWMs" ) ),
                     li( a( { href => $sample_file, rel => 'external', -target => 'blank' }, "Sample FASTA")),
                     li( a( { href => $background_file, rel => 'external', -target => 'blank' }, "Background FASTA")),
                     li( a( { href => $zip, rel => 'external', -target => 'blank' }, "Results archive")),
                               )
); # end download tab HTML
print FINDEX $download_tab;



##### --- Results tab ---
# Page title
my $main_tab_title = h3('TRAWLER\'S OVER-REPRESENTED MOTIFS');
# Tooltip text (on table header)
my $fam_txt = 'Motif family';
my $pwm_txt = 'Position Weight Matrix';
my $hit_txt = 'JASPAR (Mathelier et al., 2014), UniPROBE (Hume et al., 2015)';
my $zsc_txt = 'Over-representation score of this motif compared to its background occurrence';
my $csc_txt = 'Number of species where the motif is conserved';
# print THEAD
my $main_tab_table_thead;
if ($conservation) {
    $main_tab_table_thead = thead( Tr( th [
          div( { title => $fam_txt }, "Motif"),
          div( { title => $pwm_txt }, "PWM"),
          div( { title => $hit_txt }, "Hits against known TFBS databases"),
          div( { title => $zsc_txt }, "Z-score"),
          div( { title => $csc_txt }, "Conservation_score"),
          #'Motif', 'PWM', 'hits against known TFBS databases', 'Z-score', 'Conservation_score'
          ] ) );
}
else {
    $main_tab_table_thead = thead( Tr(th [
          div( { title => $fam_txt }, "Motif"),
          div( { title => $pwm_txt }, "PWM"),
          div( { title => $hit_txt }, "Hits against known TFBS databases"),
          div( { title => $zsc_txt }, "Z-score")
          ] ) );
}
# print TBODY
my $main_tab_table_tbody;
for my $k (keys %main_list) {
    $main_tab_table_tbody .= Tr( td( [ @{$main_list{$k}} ] ) );
}
# print main DIV
print FINDEX div( { id => 'trmain', class => "tab-pane fade in active"},
             #$main_tab_title,
             start_table( { id => 'idx', class => "table table-striped table-hover table-bordered" } ),
             $main_tab_table_thead,
             $main_tab_table_tbody,
             end_table() );




#### --- Family tabs (Ajax mode) ---
my $family_tabs;
# NOTE: div ID must match title attribute (container)
foreach my $family(keys %families) { 
  $family_tabs .= div( { id => $family, class => "tab-pane fade" }, '' );
  ## Fill in with the content we used to load from HTML
}
print FINDEX $family_tabs;

my $family_script = "<script>";
foreach my $family(keys %families) {
  $family_script .= '$("#'.$family.'").load("'.$family.'.html", function() {';
  $family_script .= "\$('#".$family."Tf').DataTable({\"order\": [[ 8, \"asc\" ]], \"lengthMenu\": [[10, 25, 50, -1], [10, 25, 50, \"All\"]]});";
  $family_script .= "\$('#".$family."Occ').DataTable( {\"lengthMenu\": [[10, 50, 100, -1], [10, 50, 100, \"All\"]]} );"; # {\"order\": [[ 6, \"desc\" ],[ 4, \"desc\" ],[ 0, \"asc\" ]]}
  $family_script .= '});';
}

$family_script .= "</script>";

print FINDEX $family_script;

#### --- Finalize tab container ---
print FINDEX "</div></div></div>"; # container div

#### --- Finalize page ---
print FINDEX "</div>"; # site-contain
print FINDEX "</div>";
print FINDEX end_html;

#### --- Close index file ---
close(FINDEX) or croak "Can't close file '$HTML_INDEX': $!";
print "html index created\n" if $DEBUG;



#############################################################
# Sub routines                                              #
#############################################################

sub loadFileToHash {
  #------------------------------------------------------------------
  #General script to load the lines of the file into a hash of arrays
  #------------------------------------------------------------------
  my ($file_to_load) = @_;

  my %returned_hash;
  open(F, $file_to_load) or croak "Can not open file ($file_to_load): $!";

  my $hitno = 0;
  while (my $ligne = <F>) {
    $hitno++;
    chomp $ligne;
    my @c = split/\t/, $ligne;
    @{$returned_hash{$hitno}} = @c;
  }
  close(F) or croak "Can't close file '$file_to_load': $!";
  return %returned_hash;

} # end loadFileToHash()


sub input_file_script {
 return <<Script;
  <script type="text/javascript">
  // <![CDATA[
    showfile('$input_file_link', 'ifile');
  // ]]>
  </script>
Script
}

sub createFamilyHTML {
  my ($family_name, $compare_family_name, $seq_family_name) = @_;

  #create Family HTML
  my $FAMHTML_INDEX = File::Spec->catfile($directory, $family_name.".html");
  open(FAMINDEX, '>'.$FAMHTML_INDEX) or croak "Can not create index.html file ($FAMHTML_INDEX): $!";
  # FIXME[YH]: remove header declaration
  #print FAMINDEX printHTMLhead();

  #header
  # FIXME[YH]: relative link to images (images folder)
   #my $image_link = $WORKING_DIR."/".$family_name."_all_motif.png";
   my $image_link = File::Spec->catfile($tcst{HTML_IMG}, $family_name . $tcst{MOTIF_PNG_EXT});

   my $PWMFAM = createPWMfile($family_name); # create PWM file for this family
   my $CLUSTFAM = createClusterfile($family_name); # create the motifs file for this family
   # create HTML link for these two files
   my $PWMlink = File::Spec->catfile($tcst{HTML_DOWNLOAD}, $PWMFAM);
   my $CLUSTERlink = File::Spec->catfile($tcst{HTML_DOWNLOAD}, $CLUSTFAM);
   print FAMINDEX table( { id => 'pwm', class => 'table center-block pwm'},
          thead(
          #Tr( [
          Tr( th( h2($family_name) ) ),
            #th([h2($family_name)]),
            #th([img({-src=>$image_link,-alt=>$image_link})]),
            #th([a({-href=>$PWMlink},'Download PWM')])
          ), # end thead
          tbody( Tr( td( img( { -src => $image_link, -alt => $image_link } ) ) ), # PWM logo
                 Tr( td( a( { href => $PWMlink, rel => 'external', -target => 'blank' }, 'Download PWM' ) ) ), # PWM file
                 Tr( td( a( { href => $CLUSTERlink, rel => 'external', -target => 'blank' }, 'Download instances (motifs)' ) ) ), # motifs file
                 Tr( td( a( { id => "txt-$family_name", href => "#/", onclick => "showPlot_$family_name();" }, 'Show motif distribution' ) ) ), # distribution plot
          ), # end tbody
        );

  # motifs distribution plot container / script
  my @fam_graph = family_stat_graph($family_name, @stat_data);
  print FAMINDEX create_graph_javascript($family_name, @fam_graph)."<br/>";

  #database hits Table
  print FAMINDEX h3('Hits against transcription factor databases');
  print FAMINDEX "<br>".$compare_family_name."<br/>";

  #sequences and conservation Table
  print FAMINDEX h3('Occurrences of the motif in the input sequences').br();

  # Print Occ table
  print FAMINDEX $seq_family_name."<br/>";

  #print FAMINDEX "</ul><br />";

  # FIXME[YH]: remove html structure
  # print FAMINDEX end_html;
  
  close(FAMINDEX) or croak "Can't close file '$FAMHTML_INDEX': $!";

  print "html $family_name created\n" if $DEBUG;

}


sub create_graph_javascript {
   my ($fname, @fam_graph) = @_;

#<a href="#" onclick="return showPlot();">Motifs distribution</a>
   my $data_gr = join ",", @fam_graph;

  return <<GraphJS;
<div id="plot-$fname" style="width:600px;height:330px;display:none" class="center-block"></div><br />


<script language="javascript" type="text/javascript">
var loaded_$fname = false;


function showPlot_$fname() {
    var x = document.getElementById("plot-$fname");
    var y = document.getElementById("txt-$fname");
    if (x.style.display === "none") { 
        x.style.display = "block";
        y.innerHTML = "Hide motif distribution"
      } else { 
        x.style.display = "none";
        y.innerHTML = "Show motif distribution"
      }
    if (loaded_$fname==false) {
      var fdata = [$data_gr];

      \$.plot(\$("#plot-$fname"),[{
        color:"#682678",
        data:fdata,bars:{show: true}}],
        {xaxis:{
          tickFormatter:function(v,axis){return v * 10},
          axisLabel: "Sequence Length (%)",
          axisLabelUseCanvas: true,
          axisLabelFontSizePixels: 13,
          axisLabelFontFamily: "'Helvetica Neue', Helvetica, Arial",
          axisLabelPadding: 20
        },yaxis:{
          axisLabel: "Number of Motifs",
          axisLabelUseCanvas: true,
          axisLabelFontSizePixels: 13,
          axisLabelFontFamily: "'Helvetica Neue', Helvetica, Arial",
          axisLabelPadding: 15,
        },grid: {
        hoverable: true,
        clickable: true
        }
      });


       var previousPoint = null, previousLabel = null;

      \$.fn.UseTooltip = function () {
            \$(this).bind("plothover", function (event, pos, item) {
                if (item) {
                    if ((previousLabel != item.series.label) || (previousPoint != item.dataIndex)) {
                        previousPoint = item.dataIndex;
                        previousLabel = item.series.label;
                        \$("#tooltip").remove();
 
                        var x = item.datapoint[0];
                        var y = item.datapoint[1];
 
                        var color = item.series.color;
 
                        //console.log(item.series.xaxis.ticks[x].label);                
 
                        showTooltip(item.pageX, item.pageY, color, y);
                    }
                } else {
                    \$("#tooltip").remove();
                    previousPoint = null;
                }
            });
        };
 
        function showTooltip(x, y, color, contents) {
            \$('<div id="tooltip">' + contents + '</div>').css({
                position: 'absolute',
                display: 'none',
                top: y - 25,
                left: x + 5,
                border: '2px solid ' + color,
                padding: '3px',
                'font-size': '9px',
                'border-radius': '5px',
                'background-color': '#fff',
                'font-family': 'Verdana, Arial, Helvetica, Tahoma, sans-serif',
                opacity: 0.9
            }).appendTo("body").fadeIn(200);
        }

        \$("#plot-$fname").UseTooltip();

      loaded_$fname = true;
    }
};
</script>
GraphJS
}



# Creates the PWM file
sub createPWMfile {
  my ($PWM_name) = @_;

  open(PWM, $PWM_FILE) or croak "Can not open .pwm file ($PWM_FILE): $!";

  # Retrieve pwm files from download directory
  my $PWM_FAMFILE_NAME = $PWM_name."_pwm.txt";
  my $PWM_FAMFILE = File::Spec->catfile($html_download_dir, $PWM_FAMFILE_NAME);

  open(FAMPWM, '>'.$PWM_FAMFILE) or croak "Can not create family.pwm file ($PWM_FAMFILE): $!";
  my $started='false';
  while (my $ligne = <PWM>) {
    if ($ligne=~/^>/){
      $started='false';
    }
    if ($ligne=~/^>$PWM_name/) {
      $started='true';
    }
    if ($started eq 'true') {
      print FAMPWM $ligne;
    }
  }
  close(PWM) or croak "Can't close file '$PWM_FILE': $!";
  close(FAMPWM) or croak "Can't close file '$PWM_FAMFILE': $!";

  return $PWM_FAMFILE_NAME;
}

# Creates the clustered motifs file
sub createClusterfile {
  my ($Clutser_name) = @_;

  open(CLUSTER, $CLUSTER_FILE_NAME) or croak "Can not open .pwm file ($CLUSTER_FILE_NAME): $!";

  # Retrieve cluster file from download directory
  my $CLUSTER_FAMFILE_NAME = $Clutser_name."_cluster.txt";
  my $CLUSTER_FAMFILE = File::Spec->catfile($html_download_dir, $CLUSTER_FAMFILE_NAME);
  open(FAMCLUSTER, '>'.$CLUSTER_FAMFILE) or croak "Can not create family.pwm file ($CLUSTER_FAMFILE): $!";
  print FAMCLUSTER "#Motif\tFamily name\tZ score\tOccurrence in the sample\tOccurrence in the background\tStrand\n";
  while (my $ligne = <CLUSTER>) {
    if ($ligne=~/$Clutser_name/) {
      print FAMCLUSTER $ligne;
    }
  }
  close(CLUSTER) or croak "Can't close file '$CLUSTER_FILE_NAME': $!";
  close(FAMCLUSTER) or croak "Can't close file '$CLUSTER_FAMFILE': $!";

  return $CLUSTER_FAMFILE_NAME;
}

sub parse_stat {

    my ($stat_file) = @_;

    open(FILE, $stat_file) or croak "Can not open STAT file ($stat_file): $!";
    my @extract;
    my $line = <FILE>; # skip header line
    while ($line = <FILE>) {
      # 0: id | 1: family | 3: start | 6: seq length
        my @array = split(/\t/,$line);
        push @extract, "$array[1];$array[0];$array[3];$array[6]";
    }
    close(FILE) or croak "Can't close STAT file '$stat_file': $!";
    # uniq and sorted
    my %seen = map { $_, 1 } @extract;
    my @uniqed = sort keys %seen;

    return @uniqed;
}

sub family_stat_graph {

    my ($family_id, @stat_array) = @_;

    my @scoring;
    foreach my $elem ( @stat_array ) {
        my @uniq_extract = split /;/, $elem;
        if ($uniq_extract[0] eq $family_id) {
            my $calc = sprintf("%.2f", ($uniq_extract[2]/$uniq_extract[3])*10);
            push @scoring, $calc;
        }
    }

    my %matrix = ();
    # generate beans
    foreach my $elem (@scoring) {
        $elem = int($elem); # absc
        if (exists $matrix{$elem}) {
          my $tmp_val = $matrix{$elem};
            $matrix{$elem} = $tmp_val + 1;
        }
        else {
          $matrix{$elem} = 1;
        }
    }

    # check all beans
    foreach(0..9) {
        if (!exists $matrix{$_}) {
            $matrix{$_} = 0;
        }
    }

    # generate data graph for javascript
    my @data_graph;
    for my $key ( sort keys %matrix ) {
        my $value = $matrix{$key};
        push @data_graph, "[$key,$value]";
    }

    return @data_graph;
}

sub msg_pipeline {
  my $msg_pipeline = <<"MSG";
  ==========
  Creating HTML output...
  ==========
MSG

  print $msg_pipeline . "\n";
}

1;
