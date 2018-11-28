#!/bin/bash
set -e
set -o pipefail

# TODO: change hard coded exclude paths into parameters
# TODO: make more generic
# TODO: parallelise
# TODO: create .md5 file per input file
# TODO: make async. i.e. webhook callback once finished

HASHFUNC="md5sum"
#HASHFUNC="xxh64sum"
THREADS=5

if test -z "$DEPLOY_ENV"; then
    echo "DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'."
    exit 1
fi

script=$(basename $0)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function write_log {
  msg="$(date +'%Y-%m-%d %H:%M:%S.%N') $script: $1"
  echo "$msg" >> $DIR/${script}.log
  if test "$DEPLOY_ENV" = "prod"; then
    echo "$msg" > /dev/udp/localhost/9999
  else
    echo "$msg"
  fi
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
  cmd="find . -not \( -path ./bcl2fastq.$HASHFUNC -prune \) -type f | parallel -j $THREADS $HASHFUNC > ./bcl2fastq.$HASHFUNC"
  write_log "INFO: Running: $cmd"
  if test "$DEPLOY_ENV" = "prod"; then
    eval "$cmd"
  else
    echo "$cmd"
  fi
elif test "$use_case" = 'runfolder'
then
  cmd="find . -not \( -path ./Thumbnail_Images -prune \) -not \( -path ./Data -prune \) -not \( -path ./runfolder.$HASHFUNC -prune \) -type f | parallel -j $THREADS $HASHFUNC > ./runfolder.$HASHFUNC"
  write_log "INFO: Running: $cmd"
  if test "$DEPLOY_ENV" = "prod"; then
    eval "$cmd"
  else
    echo "$cmd"
  fi
else
  write_log "ERROR: Not a valid use case: $use_case"
  (>&2 echo "ERROR: Not a valid use case: $use_case")
  echo " Usage: ./$script [bcl2fastq|runfolder] <directory path>"
  exit -1
fi


# write_log "INFO: All done."



# finally notify StackStorm of completion
if test "$DEPLOY_ENV" = "prod"; then
  st2_webhook_url="https://stackstorm.prod.umccr.org/api/v1/webhooks/st2"
else
  st2_webhook_url="https://stackstorm.dev.umccr.org/api/v1/webhooks/st2"
fi
webhook="curl --insecure -X POST $st2_webhook_url -H \"St2-Api-Key: $st2_api_key\" -H \"Content-Type: application/json\" --data '{\"trigger\": \"umccr.checksum\", \"payload\": {\"status\": \"$status\", \"runfolder_name\": \"$runfolder_name\", \"runfolder\": \"$runfolder_dir\", \"usecase\": \"$use_case\"}}'"

write_log "INFO: calling home: $webhook"
eval "$webhook"

write_log "INFO: All done."

