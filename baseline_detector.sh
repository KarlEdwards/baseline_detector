#!/usr/bin/env bash

# Do one or more of:
#  PARTITION  make dataset
#  FEATURES   extract features
#  CLASSIFY   classify images and evaluate the classifier performance

# --- Hard Configuration
CFGFILE=baseline_detector.cfg; echo; echo "CONFIG FILE : $CFGFILE"

# --- Utility functions for handling configuration file
function sed_escape() {
  sed -e 's/[]\/$*.^[]/\\&/g'
}

function cfg_read() { # key -> value
  KEY=$1
  test -f "$CFGFILE" && grep "^$(echo "$KEY" | sed_escape)=" "$CFGFILE" | sed "s/^$(echo "$KEY" | sed_escape)=//" | tail -1
}

# --- Read default configuration
function read_configuration(){

  PROJECTPATH=$(  cfg_read PROJECTPATH  )
  DATAPATH=$(     cfg_read DATAPATH     )
  LIBPATH=$(      cfg_read LIBPATH      )

  CELLS=$(        cfg_read CELLS        )
  BINS=$(         cfg_read BINS         )

  DATASET=$(      cfg_read DATASET      )
  KEYWORD=$(      cfg_read KEYWORD      )
  FRACTION=$(     cfg_read FRACTION     )

}

# --- Show configuration
function show_configuration(){
  echo "-------------"
  echo "PROJECTPATH : $PROJECTPATH"
  echo "DATAPATH    : $DATAPATH"
  echo "LIBPATH     : $LIBPATH"

  echo "DATASET     : $DATASET"
  echo "KEYWORD     : $KEYWORD"
  echo "FRACTION    : $FRACTION"

  echo "CELLS       : $CELLS"
  echo "BINS        : $BINS"

  A=$( [ $PARTITION == true ] && echo "-> Partition dataset" )
  B=$( [ $FEATURES  == true ] && echo "-> Make HoGs" )
  C=$( [ $CLASSIFY  == true ] && echo "-> Classify images" )
  to_do="Begin $A $B $C -> End"
  echo "-------------"
  echo 
  echo "$to_do"
  echo 

}

# --- Round a number, N, to D digits
function round() 
{
  number=$1; digits=$2
  echo $(printf %.$2f $(echo "scale="$digits";(((10^"$digits")*"$number")+0.5)/(10^"$digits")" | bc))
}

function initialize(){
  readonly PROGRAM_NAME=$(basename $0)

  PARTITION=false
  FEATURES=false
  CLASSIFY=false

  # Set some sensible defaults
  HELP=false
  CELLS=8
  BINS=8
  KEYWORD=none
  FRACTION=0.00
  
  LABEL_FILE="" 
  
  # Allow defaults to be over-ridden with a configuration file
  read_configuration

}

function usage()
{
	cat <<- EOF
	
	- - - - - - - - - - - - - - - -
	Usage: ./$PROGRAM_NAME options
	- - - - - - - - - - - - - - - -
	
	Do one or more of:
	* PARTITION  make dataset
	* FEATURES   extract features
	* CLASSIFY   classify images


	OPTIONS:
	
	One or more of these are required:
	  -p | --partition_dataset Create a new dataset, given keyword and training fraction
	  -x | --extract_features  Make Histograms of Oriented Gradients (HoGs), given cells and bins
	  -c | --classify          Classify images and evaluate the performance of the classifier
	  
	Both of these are required
	  -k | --keyword           Class label, i.e., disc, player, jump, throw, catch, etc.
	  -f | --fraction          Training fraction, portion of overall number of records for training
	
	Required for partitioning a new dataset
	
	  -l | --label_file        Contains class labels
	
	Both of these are required for HoGs
	  -w | --cells             
	  -b | --bins

	  -h | --help              Show this information
	  -n | --dry-run           Don\'t do anything; just see what would be done
	
	Examples:
	  Create a new dataset of images depicting a disc (or not), and using 75% of the images for training
	   ./$PROGRAM_NAME --partition_dataset --keyword disc --fraction .75
	   
	  Extract features (histograms of oriented gradients) using 8 cells and 9 bins
	   ./$PROGRAM_NAME --extract_features --cells 8 --bins 9
	
	  Classify images and evaluate classifier performance
	   ./$PROGRAM_NAME --classify 
	   ./$PROGRAM_NAME -c
	  	  
	  Any number of cells; specific number of bins
	   ./$PROGRAM_NAME -c --cells "*" --bins 8 -f .8
	EOF
}

# --- Create a subdirectory if it does not already exist
function make_directory_if_not_existing()
{
  [ -d $1 ] && echo "Using existing subdirectory" $1 || (echo "Creating subdirectory " $1; mkdir $1)
  echo 
}

function new_dataset(){
  echo "LABEL_FILE: $LABEL_FILE"
  if [ "$LABEL_FILE" == "" ]; then echo "--label_file FILE_NAME is required."; exit; fi
  if [ ! -e "$LABEL_FILE" ]; then echo "$LABEL_FILE not found."; exit; fi
  cmd="$partitionexec $DATASET$KEYWORD $LABEL_FILE $FRACTION"
  if [ "$DRY_RUN" == "true" ]; then
    echo "DRY RUN: $to_do"
    echo $cmd
    exit
  else
    echo "Call partition..."
    $cmd
  fi
}

# --- Make histograms of oriented gradients ( HoGs )
function extract_features(){
  if [ "$DRY_RUN" == "true" ]; then
    echo "DRY RUN: $to_do"
    exit
  else
    group="$PROJECTPATH"$dataset$destination
    subgroup=$group/cells"$CELLS"_bins"$BINS"

    echo "   group: $group"
    echo "subgroup: $subgroup"

    make_directory_if_not_existing $subgroup
    for file in training_pos training_neg testing_pos testing_neg; do

      $hogexec \
        --data_path=$image_path --cells=$CELLS --bins=$BINS \
        --output=$subgroup/"$file".csv --input=$group/"$file".txt  
  
    done 
  fi
}

function classify_images(){
  if [ "$DRY_RUN" == "true" ]; then
    echo "DRY RUN: $to_do"
    exit
  else
    pattern="$DATASET""$destination"/"cells""$CELLS""_bins""$BINS"
    score_parameters="ls -d $pattern*"
    $score_parameters | xargs -n 1 $svmexec --lib_path=$LIBPATH --summary_file=summary.csv
  fi
}

# -----------------------------------------------
#           M A I N   F U N C T I O N
# -----------------------------------------------

# --- Initialize
DRY_RUN=false;
PUBLISH=false;
HELP=false;

# --- Get command-line
  initialize

  while true; do
    case "$1" in
      -cfg | --config_file ) CFGFILE="$2"; shift 2 ;;
      -l | --label_file )   LABEL_FILE="$2"; shift 2 ; echo 'Label file input !' ;;
      -p | --partition )    PARTITION=true;  shift  ; echo 'Partition input !'  ;;
      -x | --hogs      )     FEATURES=true;  shift   ;;
      -c | --classify  )     CLASSIFY=true;  shift   ;;
      -d | --dataset   )      DATASET="$2/";   shift 2 ;;
      -k | --keyword   )      KEYWORD="$2";    shift 2 ;;
      -f | --fraction  )     FRACTION="$2";    shift 2 ;;
      -w | --cells     )        CELLS="$2";    shift 2 ;;
      -b | --bins      )         BINS="$2";    shift 2 ;;
      -h | --help      )         HELP=true;  shift; usage; exit ;;
      -n | --dry_run   )      DRY_RUN=true;  shift; ;;
      --               )                     shift; break ;;
      *                ) break ;;
    esac
  done

  image_path="$PROJECTPATH""$DATAPATH"
  partitionexec="$PROJECTPATH""$LIBPATH""partition_data_two_class.sh"
  hogexec="$PROJECTPATH""$LIBPATH""HoG.R"
  svmexec="$PROJECTPATH""$LIBPATH"/"score.R"
  destination="$DATASET"$(printf $KEYWORD%s $(echo "$(round 100*$FRACTION 0)" | bc))

show_configuration

echo "destination: $destination"

[ $PARTITION == true ] && new_dataset
[ $FEATURES  == true ] && extract_features
[ $CLASSIFY  == true ] && classify_images
