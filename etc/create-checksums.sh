#!/bin/bash

# TODO: change hard coded exclude paths into parameters
# TODO: make more generic
# TODO: parallelise
# TODO: create .md5 file per input file
# TODO: make async. i.e. webhook callback once finished


script=$(basename $0)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
function write_log {
  msg="$(date +'%Y-%m-%d %H:%M:%S.%N') $script: $1"
  echo "$msg" > /dev/udp/localhost/9999
  echo "$msg" >> $DIR/${script}.log
}
write_log "INFO: Invocation with parameters: $*"

use_case="$1"
directory="$2"


if test "$directory" && test -d "$directory"
then
  write_log "INFO: Moving to $directory"
  cd "$directory"
else
  write_log "ERROR: Not a valid directory: $directory"
  (>&2 echo "ERROR: Not a valid directory: $directory")
  exit -1
fi



if test "$use_case" = 'bcl2fastq'
then
  cmd="find . -not \( -path ./bcl2fastq.md5 -prune \) -type f -exec md5sum '{}' \; > ./bcl2fastq.md5"
  write_log "INFO: Running: $cmd"
  eval "$cmd"
elif test "$use_case" = 'runfolder'
then
  cmd="find . -not \( -path ./Thumbnail_Images -prune \) -not \( -path ./Data -prune \) -not \( -path ./runfolder.md5 -prune \) -type f -exec md5sum '{}' \; > ./runfolder.md5"
  write_log "INFO: Running: $cmd"
  eval "$cmd"
else
  write_log "ERROR: Not a valid use case: $use_case"
  (>&2 echo "ERROR: Not a valid use case: $use_case")
  echo " Usage: ./$script [bcl2fastq|runfolder] <directory path>"
  exit -1
fi
write_log "INFO: All done."
