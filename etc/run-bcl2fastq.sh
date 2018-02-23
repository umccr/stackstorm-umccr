#!/bin/bash

# write the script logs next to the script itself
script=$(basename $0)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
function write_log {
  echo "$(date +'%Y-%m-%d %H:%M:%S.%N') $script: $1" > /dev/udp/localhost/9999
  echo "$(date +'%Y-%m-%d %H:%M:%S.%N'): $1" >> $DIR/${script}.log
}

write_log "INFO: Invocation with parameters: $*"

if [[ $# -lt 4 ]]; then
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
      output_dir="$2"
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

if [[ -z "$st2_api_key" ]]; then
  write_log "ERROR: Parameter 'st2_api_key' missing"
  echo "You have to provide an st2 api key!"
  exit -1
fi


# make sure the output directory exists
mkdir_command="mkdir -p \"$output_dir\""
write_log "INFO: creating output dir: $mkdir_command"
eval $mkdir_command

# run the actual conversion
cmd="docker run --rm -v $runfolder_dir:$runfolder_dir:ro -v $output_dir:$output_dir umccr/bcl2fastq:$bcl2fastq_version -R $runfolder_dir -o $output_dir ${optional_args[*]} >& $output_dir/${runfolder_name}.log"
write_log "INFO: running command: $cmd"
write_log "INFO: writing bcl2fastq logs to: $output_dir/${runfolder_name}.log"
eval $cmd
ret_code=$?

if [ $ret_code != 0 ]; then
  status="error"
  write_log "ERROR: bcl2fastq conversion failed with exit code: $ret_code"
else
  status="done"
  write_log "INFO: bcl2fastq conversion succeeded"
fi

# finally notify StackStorm of completion
webhook="curl --insecure -X POST https://arteria.umccr.nopcode.org/api/v1/webhooks/st2 -H \"St2-Api-Key: $st2_api_key\" -H \"Content-Type: application/json\" --data '{\"trigger\": \"umccr.bcl2fastq\", \"payload\": {\"status\": \"$status\", \"runfolder_name\": \"$runfolder_name\", \"runfolder\": \"$runfolder_dir\"}}'"
write_log "INFO: calling home: $webhook"
eval $webhook
