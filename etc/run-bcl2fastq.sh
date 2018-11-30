#!/bin/bash
set -e
set -o pipefail

script_name=$(basename $0)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
lock_dir="$DIR/${script_name}_lock"
lock_check_sleep_time=300
script_pid=$$

FLAG_WGS="--no-lane-splitting"
FLAG_10X="--no-lane-splitting --minimum-trimmed-read-length=8 --mask-short-adapter-reads=8 --ignore-missing-positions --ignore-missing-controls --ignore-missing-filter --ignore-missing-bcls"

# NOTE: endpont URL for webhook is hard coded and therefore fixed to the dev server.

if test -z "$DEPLOY_ENV"; then
    echo "DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'."
    exit 1
fi

function write_log {
  msg="$(date +'%Y-%m-%d %H:%M:%S.%N') $script_name: $1"
  echo "$msg" >> $DIR/${script_name}.log
  if test "$DEPLOY_ENV" = "prod"; then
    echo "$msg" > /dev/udp/localhost/9999
  else
    echo "$msg"
  fi
}

write_log "INFO: Invocation with parameters: $*"

if [[ $# -lt 8 ]]; then
  write_log "ERROR: Insufficient parameters"
  echo "A minimum of 4 arguments are required!"
  echo "  1) The runfolder directory [-R|--runfolder-dir]"
  echo "  2) The runfolder name [-n|--runfolder-name]"
  echo "  3) The output directory [-o|--output-dir]"
  echo "  4) An st2 api key [-k|--st2-api-key]"
  exit -1
fi

bcl2fastq_version="latest"
optional_args=()
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    -v|--bcl2fastq-version)
      bcl2fastq_version="$2"
      shift # past argument
      shift # past value
      ;;
    -o|--output-dir)
      output_dir="${2%/}" # strip trailing slash if present
      shift # past argument
      shift # past value
      ;;
    -R|--runfolder-dir)
      runfolder_dir="$2"
      shift # past argument
      shift # past value
      ;;
    -n|--runfolder-name)
      runfolder_name="$2"
      shift # past argument
      shift # past value
      ;;
    -k|--st2-api-key)
      st2_api_key="$2"
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option (everything else)
      optional_args+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

if [[ -z "$output_dir" ]]; then
  write_log "ERROR: Parameter 'output_dir' missing"
  echo "You have to define an output directory!"
  exit -1
fi

if [[ -z "$runfolder_dir" ]]; then
  write_log "ERROR: Parameter 'runfolder_dir' missing"
  echo "You have to define a runfolder directory!"
  exit -1
fi

if [[ -z "$runfolder_name" ]]; then
  write_log "ERROR: Parameter 'runfolder_name' missing"
  echo "You have to define a runfolder name!"
  exit -1
fi

# TODO: just a sanity check
# TODO: could scrap runfolder_name parameter and extract name from runfolder_dir instead
# TODO: should check that we really have a runfolder dir or just let the conversion fail?
if [[ "$(basename $runfolder_dir)" != "$runfolder_name" ]]; then
  write_log "ERROR: The provided runfolder directory does not match the provided runfolder name!"
  echo "ERROR: The provided runfolder directory does not match the provided runfolder name!"
  exit -1
fi

if [[ -z "$st2_api_key" ]]; then
  write_log "ERROR: Parameter 'st2_api_key' missing"
  echo "You have to provide an st2 api key!"
  exit -1
fi

# Input parameters are all OK, we can start the actual process

# Aquire a lock to prevent parallel script execution
write_log "INFO: $script_pid Aquiring lock..."
while ! mkdir "$lock_dir"; do
  write_log "DEBUG: $script_pid is locked and waiting ..."
  sleep $lock_check_sleep_time
done
write_log "INFO: $script_pid Aquired lock"

shopt -s nullglob
custom_samplesheets=("${runfolder_dir}"/SampleSheet.csv.custom*)
num_custom_samplesheets=${#custom_samplesheets[@]}

# we distinguish the 'normal' case, when there are no custom sample sheets
# from the case where there are custom sample sheets
if test "$num_custom_samplesheets" -gt 0; then

  write_log "INFO: Custom sample sheets detected. Starting conversion."

  for samplesheet in "${custom_samplesheets[@]}"; do
    write_log "INFO: Processing sample sheet: $samplesheet"
    custom_tag=${samplesheet#*SampleSheet.csv.}
    write_log "DEBUG: Extracted sample sheet tag: $custom_tag"

    # make sure the output directory exists
    mkdir_command="mkdir -p \"$output_dir\""
    write_log "INFO: creating output dir: $mkdir_command"
    eval "$mkdir_command"

    if [[ $custom_tag = *"10X"* ]]; then
      write_log "INFO: 10X dataset detected."
      additional_params="$FLAG_10X"
    elif [[ $custom_tag = *"truseq"* ]]; then
      write_log "INFO: truseq dataset detected."
      additional_params="$FLAG_WGS"
    else
      write_log "INFO: Neither 10X nor truseq detected! Running default."
      additional_params=""
    fi
    # run the actual conversion
    log_file="$output_dir/${runfolder_name}_${custom_tag}.log"
    echo "Starting conversion of $runfolder_name" >> $log_file
    cmd="docker run --rm -v $runfolder_dir:$runfolder_dir:ro -v $output_dir:$output_dir umccr/bcl2fastq:$bcl2fastq_version -R $runfolder_dir -o $output_dir --stats-dir=$output_dir/Stats_${custom_tag} --reports-dir=$output_dir/Reports_${custom_tag} ${optional_args[*]} $additional_params --sample-sheet $samplesheet >> $log_file 2>&1"
    write_log "INFO: running command: $cmd"
    write_log "INFO: writing bcl2fastq logs to: $log_file"
    if test "$DEPLOY_ENV" = "prod"; then
      eval "$cmd"
      ret_code=$?
    else
      echo "$cmd"
      ret_code=0
    fi

    if [ $ret_code != 0 ]; then
      status="error"
      write_log "ERROR: bcl2fastq conversion of $samplesheet failed with exit code: $ret_code."
      break # we are conservative and don't continue if there is an error on wich any conversion
    else
      status="done"
      write_log "INFO: bcl2fastq conversion of $samplesheet succeeded."
    fi

    # clean-up undetermined
    write_log "INFO: Cleaning up undetermined fastq files."
    cmd="rm -f $output_dir/Undetermined*"
    if test "$DEPLOY_ENV" = "prod"; then
      eval "$cmd"
    else
      echo "$cmd"
    fi

  done

else
  write_log "ERROR: No custom sample sheet found. Make sure one exists!"
fi

# not that the conversion is finished we can release the resources
write_log "INFO: releasing lock"
rm -rf $lock_dir


# finally notify StackStorm of completion
if test "$DEPLOY_ENV" = "prod"; then
  st2_webhook_url="https://stackstorm.prod.umccr.org/api/v1/webhooks/st2"
else
  st2_webhook_url="https://stackstorm.dev.umccr.org/api/v1/webhooks/st2"
fi
webhook="curl --insecure -X POST $st2_webhook_url -H \"St2-Api-Key: $st2_api_key\" -H \"Content-Type: application/json\" --data '{\"trigger\": \"umccr.pipeline\", \"payload\": {\"task\": \"bcl2fastq_start\", \"status\": \"$status\", \"runfolder_name\": \"$runfolder_name\", \"runfolder\": \"$runfolder_dir\", \"out_dir\": \"${output_dir}\"}}'"

write_log "INFO: calling home: $webhook"
eval "$webhook"

write_log "INFO: All done."
