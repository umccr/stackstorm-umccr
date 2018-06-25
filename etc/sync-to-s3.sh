#!/bin/bash
set -e
set -o pipefail

script=$(basename $0)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
function write_log {
  msg="$(date +'%Y-%m-%d %H:%M:%S.%N') $script: $1"
  # echo "$msg" > /dev/udp/localhost/9999
  # echo "$msg" >> $DIR/${script}.log
  echo "$msg"
}
write_log "INFO: Invocation with parameters: $*"

if test "$#" -lt 8; then
  write_log "ERROR: Insufficient parameters"
  echo "Number of provided parameters: $(($# / 2))"
  echo "A minimum of 4 arguments are required!"
  echo "  - The destination bucket [-b|--bucket]"
  echo "  - The destination path [-d|--dest-dir]"
  echo "  - The source path [-s|--source-dir]"
  echo "  - The AWS account number to upload to [-a|--account]"
  echo "  - (optional) The sync exclusions, in aws syntax [-e|--excludes]"
  echo "  - (optional) Force write to output directory, even if it does not match the input name [-f|--force]"
  exit -1
fi

force_write="0"
excludes=()
optional_args=()
while test "$#" -gt 0; do
  key="$1"

  case $key in
    -e|--excludes)
      excludes+=("$2")
      shift # past argument
      shift # past value
      ;;
    -b|--bucket)
      bucket="$2"
      shift # past argument
      shift # past value
      ;;
    -s|--source_path)
      source_path="$2"
      shift # past argument
      shift # past value
      ;;
    -d|--dest_path)
      dest_path="$2"
      shift # past argument
      shift # past value
      ;;
    -a|--account)
      aws_acc="$2"
      shift # past argument
      shift # past value
      ;;
    -f|--force)
      force_write="1"
      shift # past argument
      ;;
    *)    # unknown option (everything else)
      optional_args+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done
echo "Check parameters"

if test ! "$bucket"
then
  write_log "ERROR: Parameter 'bucket' missing"
  echo "You have to provide a bucket parameter!"
  exit -1
fi

if test ! "$dest_path"
then
  write_log "ERROR: Parameter 'dest-dir' missing"
  echo "You have to provide a dest-dir parameter!"
  exit -1
fi

if test ! "$source_path"
then
  write_log "ERROR: Parameter 'source-dir' missing"
  echo "You have to provide at least one source-dir parameter!"
  exit -1
fi

if test "${source_path#*$dest_path}" == "$source_path"
then
  write_log "WARNING: Destination $dest_path and source $source_path to not match!"
  if test $force_write = "0"
  then
    write_log "Aborting!"
    exit 1
  fi
fi

if test ! "$aws_acc"
then
  write_log "ERROR: Parameter 'account' missing"
  echo "You have to provide the account parameter!"
  exit -1
fi

log_file_name=$(echo "$dest_path" | tr \/ _)

# attempt to assume the ops admin role in dev
export AWS_REGION=ap-southeast-2

temp_role=$(aws sts assume-role --role-arn "arn:aws:iam::$aws_acc:role/fastq_data_uploader" --role-session-name "temp_session" --duration-seconds=21600)

export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq .Credentials.AccessKeyId | xargs)
export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq .Credentials.SecretAccessKey | xargs)
export AWS_SESSION_TOKEN=$(echo $temp_role | jq .Credentials.SessionToken | xargs)


test_cmd="aws s3 ls s3://$bucket"
eval "$test_cmd"
ret_code=$?

if [ $ret_code != 0 ]; then
  write_log "ERROR: Could not access bucket $bucket."
  exit 1
fi

# configuring AWS S3 command
aws configure set default.s3.max_concurrent_requests 10
aws configure set default.s3.max_queue_size 10000
aws configure set default.s3.multipart_threshold 64MB
aws configure set default.s3.multipart_chunksize 16MB
aws configure set default.s3.max_bandwidth 800MB/s

# build the command
cmd="aws s3 sync --no-progress --dryrun --no-follow-symlinks"
for i in "${excludes[@]}"
do
  cmd+=" --exclude $i"
done
# TODO: find a better place to store the log file
# TODO: perhaps add a timestamp to the log file name
cmd+=" $source_path s3://$bucket/$dest_path > ${log_file_name}.log"

write_log "INFO: Running: $cmd"
#eval "$cmd"
echo "$cmd"

# TODO: add wbhook callback to ST2 to make async

write_log "INFO: All done."
