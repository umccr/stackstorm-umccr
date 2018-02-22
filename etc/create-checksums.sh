#!/bin/bash

use_case=$1
directory=$2


if test $directory && test -d $directory
then
  cd $directory
else
  echo "You need to specify a use case and a base directory"
  exit -1
fi



if test $use_case = 'bcl2fastq'
then
  #find . -not \( -path ./bcl2fastq.md5 -prune \) -type f -exec md5sum '{}' \; > ./bcl2fastq.md5
  find . -not \( -path ./bcl2fastq.md5 -prune \) -type f | wc -l
elif test $use_case = 'runfolder'
then
  #find . -not \( -path ./Thumbnail_Images -prune \) -not \( -path ./Data -prune \) -not \( -path ./runfolder.md5 -prune \) -type f -exec md5sum '{}' \; > ./runfolder.md5
  find . -not \( -path ./Thumbnail_Images -prune \) -not \( -path ./Data -prune \) -not \( -path ./runfolder.md5 -prune \) -type f | wc -l
else
  echo "Not a valid useage!"
  echo " Usage: ./create-checksums.sh [bcl2fastq|runfolder] <directory path>"
  exit -1
fi
