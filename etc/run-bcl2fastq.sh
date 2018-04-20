#!/bin/bash

# NOTE: endpont URL for webhook is hard coded and therefore fixed to the dev server.

script_name=$(basename $0)
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
lock_dir="$script_dir/${script_name}_lock"
lock_check_sleep_time=300
script_pid=$$

function write_log {
  msg="$(date +'%Y-%m-%d %H:%M:%S.%N') $script_name $script_pid: $1"
  echo "$msg" >> $script_dir/${script_name}.log
  echo "$msg"
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
out_dirs=() # collect the generated output directories, as they are needed in further pipeline steps
if test "$num_custom_samplesheets" -gt 0; then

  write_log "INFO: Custom sample sheets detected."

  for samplesheet in "${custom_samplesheets[@]}"; do
    write_log "INFO: Processing sample sheet: $samplesheet"
    custom_tag=${samplesheet#*SampleSheet.csv.}
    write_log "DEBUG: Extracted sample sheet tag: $custom_tag"
    custom_output_dir="${output_dir}_$custom_tag"
    out_dirs+=("$custom_output_dir")


    # make sure the output directory exists
    mkdir_command="mkdir -p \"$custom_output_dir\""
    write_log "INFO: creating output dir: $mkdir_command"
    eval "$mkdir_command"

    # run the actual conversion
    cmd="docker run --rm -v $runfolder_dir:$runfolder_dir:ro -v $custom_output_dir:$custom_output_dir umccr/bcl2fastq:$bcl2fastq_version -R $runfolder_dir -o $custom_output_dir ${optional_args[*]} --sample-sheet $samplesheet >& $custom_output_dir/${runfolder_name}.log"
    write_log "INFO: running command: $cmd"
    write_log "INFO: writing bcl2fastq logs to: $custom_output_dir/${runfolder_name}.log"
    #eval "$cmd"
    ret_code=0

    if [ $ret_code != 0 ]; then
      status="error"
      write_log "ERROR: bcl2fastq conversion of $samplesheet failed with exit code: $ret_code."
      break # we are conservative and don't continue if there is an error on wich any conversion
    else
      status="done"
      write_log "INFO: bcl2fastq conversion of $samplesheet succeeded."
    fi

  done

else
  write_log "INFO: No custom sample sheet. Assuming default."

  # make sure the output directory exists
  out_dirs+=("$output_dir")
  mkdir_command="mkdir -p $output_dir"
  write_log "INFO: creating output dir: $mkdir_command"
  eval "$mkdir_command"

  # run the actual conversion
  cmd="docker run --rm -v $runfolder_dir:$runfolder_dir:ro -v $output_dir:$output_dir umccr/bcl2fastq:$bcl2fastq_version -R $runfolder_dir -o $output_dir ${optional_args[*]} >& $output_dir/${runfolder_name}.log"
  write_log "INFO: running command: $cmd"
  write_log "INFO: writing bcl2fastq logs to: $output_dir/${runfolder_name}.log"
  #eval "$cmd"
  ret_code=0


  if [ $ret_code != 0 ]; then
    status="error"
    write_log "ERROR: bcl2fastq conversion failed with exit code: $ret_code"
  else
    status="done"
    write_log "INFO: bcl2fastq conversion succeeded"
  fi

fi

# not that the conversion is finished we can release the resources
write_log "INFO: releasing lock"
rm -rf $lock_dir

bcl2fastq_output_dirs=""
for path in "${out_dirs[@]}"; do
  bcl2fastq_output_dirs="${bcl2fastq_output_dirs}${path},"
done
bcl2fastq_output_dirs="${bcl2fastq_output_dirs::-1}"


# finally notify StackStorm of completion
webhook="curl --insecure -X POST https://stackstorm.dev.umccr.org/api/v1/webhooks/st2 -H \"St2-Api-Key: $st2_api_key\" -H \"Content-Type: application/json\" --data '{\"trigger\": \"umccr.bcl2fastq\", \"payload\": {\"status\": \"$status\", \"runfolder_name\": \"$runfolder_name\", \"runfolder\": \"$runfolder_dir\", \"out_dirs\": \"${bcl2fastq_output_dirs}\"}}'"
write_log "INFO: calling home: $webhook"
eval "$webhook"

write_log "INFO: All done."
