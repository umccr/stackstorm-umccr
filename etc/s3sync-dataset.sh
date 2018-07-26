#!/bin/bash
set -e
set -o pipefail

################################################################################
# Script to sync a sequencing run plus FASTQ data from novastor to S3
# usage:  <script> <runfolder name>
# e.g. : ./s3sync-dataset.sh 180628_A00130_0066_AH5FJJDSXX

fastq_data_base="/storage/shared/bcl2fastq_output"
raw_data_base="/storage/shared/raw/Baymax"

runfolder="$1"

echo "./sync-to-s3.sh -s $raw_data_base/$runfolder -d $runfolder -b umccr-fastq-data-prod  -a 472057503814 -e 'Data/*' -e 'Thumbnail_Images/*' &"

fastq_dirs=($(ls -d1 ${fastq_data_base}/${runfolder}*))

for fastq_dir in "${fastq_dirs[@]}"; do 
  fastq=$(basename "$fastq_dir")
  echo "./sync-to-s3.sh -s $fastq_data_base/$fastq -d $runfolder/$fastq -b umccr-fastq-data-prod  -a 472057503814 -f &"
done
