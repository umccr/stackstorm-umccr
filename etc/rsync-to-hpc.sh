#!/bin/bash
set -e
set -o pipefail

# TODO: make async, i.e. webhook callback once finished
# TODO: parallelise (for example sync each fastq file separately?)

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

if test "$#" -lt 8; then
  write_log "ERROR: Insufficient parameters"
  echo "A minimum of 4 arguments are required!"
  echo "  - The destination host [-d|--dest_host]"
  echo "  - The ssh user [-u|--ssh_user]"
  echo "  - The destination path [-p|--dest_path]"
  echo "  - The source paths [-s|--source_path]"
  echo "  - (optional) The rsync exclusions [-x|--excludes]"
  exit -1
fi

optional_args=()
while test "$#" -gt 0; do
  key="$1"

  case $key in
    -x|--excludes)
      excludes="$2"
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
    *)    # unknown option (everything else)
      optional_args+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

if test ! "$excludes"
then
  excludes=""
fi

if test ! "$dest_host"
then
  write_log "ERROR: Parameter 'dest_host' missing"
  echo "You have to provide a dest_host parameter!"
  exit -1
fi

if test ! "$ssh_user"
then
  write_log "ERROR: Parameter 'ssh_user' missing"
  echo "You have to provide a ssh_user parameter!"
  exit -1
fi

if test ! "$dest_path"
then
  write_log "ERROR: Parameter 'dest_path' missing"
  echo "You have to provide a dest_path parameter!"
  exit -1
fi

if test ! "$source_path"
then
  write_log "ERROR: Parameter 'source_path' missing"
  echo "You have to provide a source_path parameter!"
  exit -1
fi

cmd="rsync -avh $excludes $source_path -e \"ssh\" $ssh_user@$dest_host:$dest_path"
write_log "INFO: Running: $cmd"
if test "$DEPLOY_ENV" = "prod"; then
  eval "$cmd"
else
  echo "$cmd"
fi

write_log "INFO: All done."
