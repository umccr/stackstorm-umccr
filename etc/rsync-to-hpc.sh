#!/bin/bash
set -e
set -o pipefail

# TODO: make async, i.e. webhook callback once finished
# TODO: parallelise (for example sync each fastq file separately?)
# TODO: refactor to allow multiple exclude parameters instead of squashing everything into one

if test -z "$DEPLOY_ENV"; then
    echo "DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'."
    exit 1
fi
if test "$DEPLOY_ENV" = "dev"; then
  # Wait a bit to simulate work (and avoid tasks running too close to each other)
  sleep 5
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

# Apply regex to truncate the ST2 API key, to prevent it from being stored in logs
paramstring=$(echo "$*" | perl -pe  's/(-k|--st2-api-key) ([a-zA-Z0-9]{10})[a-zA-Z0-9]+/$1 $2.../g')
write_log "INFO: Invocation with parameters: $paramstring"

if test "$#" -lt 8; then
  write_log "ERROR: Insufficient parameters"
  echo "A minimum of 4 arguments are required!"
  echo "  - The destination host [-d|--dest_host]"
  echo "  - The ssh user [-u|--ssh_user]"
  echo "  - The destination path [-p|--dest_path]"
  echo "  - The source paths [-s|--source_path]"
  echo "  - The runfolder name [-n|--runfolder-name]"
  echo "  - An st2 api key [-k|--st2-api-key]"
  echo "  - The use case, either 'runfolder' or 'bcl2fastq' [-c|--usecase]"
  echo "  - (optional) The rsync exclusions [-x|--excludes]"
  exit -1
fi

excludes=()
optional_args=()
while test "$#" -gt 0; do
  key="$1"

  case $key in
    -x|--excludes)
      excludes+=("$2")
      shift # past argument
      shift # past value
      ;;
    -d|--dest_host)
      dest_host="$2"
      shift # past argument
      shift # past value
      ;;
    -u|--ssh_user)
      ssh_user="$2"
      shift # past argument
      shift # past value
      ;;
    -p|--dest_path)
      dest_path="$2"
      shift # past argument
      shift # past value
      ;;
    -s|--source_path)
      source_path="$2"
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
    -c|--usecase)
      use_case="$2"
      shift # past argument
      shift # past value
      ;;
    *)    # unknown option (everything else)
      optional_args+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

if test ! "$excludes"; then
  excludes=""
fi

if test ! "$dest_host"; then
  write_log "ERROR: Parameter 'dest_host' missing"
  echo "You have to provide a dest_host parameter!"
  exit -1
fi

if test ! "$ssh_user"; then
  write_log "ERROR: Parameter 'ssh_user' missing"
  echo "You have to provide a ssh_user parameter!"
  exit -1
fi

if test ! "$dest_path"; then
  write_log "ERROR: Parameter 'dest_path' missing"
  echo "You have to provide a dest_path parameter!"
  exit -1
fi

if test ! "$source_path"; then
  write_log "ERROR: Parameter 'source_path' missing"
  echo "You have to provide a source_path parameter!"
  exit -1
fi

if [[ -z "$runfolder_name" ]]; then
  write_log "ERROR: Parameter 'runfolder_name' missing"
  echo "You have to define a runfolder name!"
  exit -1
fi

# TODO: just a sanity check
# TODO: could scrap runfolder_name parameter and extract name from source_path instead, as this is the current convention
# TODO: check that the runfolder dir exists or just let the conversion fail?
if [[ "$(basename $source_path)" != "$runfolder_name" ]]; then
  write_log "ERROR: The provided source directory does not match the provided runfolder name!"
  echo "ERROR: The provided runfolder directory does not match the provided runfolder name!"
  exit -1
fi

if [[ -z "$st2_api_key" ]]; then
  write_log "ERROR: Parameter 'st2_api_key' missing"
  echo "You have to provide an st2 api key!"
  exit -1
fi

if [[ -z "$use_case" ]]; then
  write_log "ERROR: Parameter 'usecase' missing"
  echo "You have to provide a use case!"
  exit -1
fi
if [[ "$use_case" = "runfolder" -o "$use_case" = "bcl2fastq" ]]; then
  echo "Executing use case $use_case"
else
  write_log "ERROR: Unrecognised use case: $use_case!"
  exit -1
fi

cmd="rsync -avh"
for i in "${excludes[@]}"; do
  cmd+=" --exclude $i"
done
cmd+=" $source_path -e \"ssh\" $ssh_user@$dest_host:$dest_path"


write_log "INFO: Running: $cmd"
if test "$DEPLOY_ENV" = "prod"; then
  eval "$cmd"
  exit_status="$?"
else
  echo "$cmd"
  exit_status="$?"
fi

if test "$exit_status" != "0"; then
  status="failure"
else
  status="success"
fi

# finally notify StackStorm of completion
if test "$DEPLOY_ENV" = "prod"; then
  st2_webhook_url="https://stackstorm.prod.umccr.org/api/v1/webhooks/st2"
else
  st2_webhook_url="https://stackstorm.dev.umccr.org/api/v1/webhooks/st2"
fi
webhook="curl --insecure -X POST $st2_webhook_url -H \"St2-Api-Key: $st2_api_key\" -H \"Content-Type: application/json\" --data '{\"trigger\": \"umccr.pipeline\", \"payload\": {\"task\": \"rsync2hpc.$use_case\", \"status\": \"$status\", \"runfolder_name\": \"$runfolder_name\"}}'"

write_log "INFO: calling home: $webhook"
eval "$webhook"


write_log "INFO: All done."
