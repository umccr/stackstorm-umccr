#!/bin/bash

if [[ $# -lt 6 ]]; then
  echo "A minimum of 5 arguments are required!"
  echo "  - The rsync exclusions [-x|--excludes]"
  echo "  - The destination host [-d|--dest_host]"
  echo "  - The ssh user [-u|--ssh_user]"
  echo "  - The destination path [-p|--dest_path]"
  echo "  - The source paths [-s|--source_paths]"
  exit -1
fi

bcl2fastq_version="latest"
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
  echo "You have to provide a excludes parameter!"
  exit -1
fi

if test ! "$dest_host"
then
  echo "You have to provide a dest_host parameter!"
  exit -1
fi

if test ! "$ssh_user"
then
  echo "You have to provide a ssh_user parameter!"
  exit -1
fi

if test ! "$dest_path"
then
  echo "You have to provide a dest_path parameter!"
  exit -1
fi

if test ! "$source_paths"
then
  echo "You have to provide a source_paths parameter!"
  exit -1
fi

cmd="rsync -avzh --append-verify $excludes $source_paths -e \"ssh\" $ssh_user@$dest_host:$dest_path"
# eval $cmd
echo "$cmd"
