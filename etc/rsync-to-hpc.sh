#!/bin/bash

script=$(basename $0)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
function write_log {
  echo "$(date +'%Y-%m-%d %H:%M:%S.%N') $script: $1" > /dev/udp/localhost/9999
  echo "$(date +'%Y-%m-%d %H:%M:%S.%N') $script: $1" >> $DIR/${script}.log
}
write_log "INFO: Invocation with parameters: $*"

if [[ $# -lt 6 ]]; then
  write_log "ERROR: Insufficient parameters"
  echo "A minimum of 5 arguments are required!"
  echo "  - The rsync exclusions [-x|--excludes]"
  echo "  - The destination host [-d|--dest_host]"
  echo "  - The ssh user [-u|--ssh_user]"
  echo "  - The destination path [-p|--dest_path]"
  echo "  - The source paths [-s|--source_paths]"
  exit -1
fi

optional_args=()
while [[ $# -gt 0 ]]
do
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
    -s|--source_paths)
      source_paths="$2"
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
  write_log "ERROR: Parameter 'excludes' missing"
  echo "You have to provide a excludes parameter!"
  exit -1
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

if test ! "$source_paths"
then
  write_log "ERROR: Parameter 'source_paths' missing"
  echo "You have to provide a source_paths parameter!"
  exit -1
fi

cmd="rsync -avzh --append-verify $excludes $source_paths -e \"ssh\" $ssh_user@$dest_host:$dest_path"
write_log "INFO: Running: $cmd"
# eval $cmd
echo "$cmd"
