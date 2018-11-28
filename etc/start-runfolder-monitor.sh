#!/bin/bash
set -e
set -o pipefail

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


if test "$DEPLOY_ENV" = "prod"; then
    runfolder_base="/storage/shared/raw/Baymax"
    status_base="/opt/Pipeline/prod/runfolder-status"
    port=8888
    tag="storage-shared-monitor"
    datadog_label="com.datadoghq.ad.logs='"'[{"source": "arteria_runfolder", "service": "arteria_share_monitor_prod"}]'"'" # composition of 3 strings: ""''"" (to avoid escaping of double quotes in json)
else
    runfolder_base="/storage/shared/dev/Baymax"
    status_base="/opt/Pipeline/dev/runfolder-status"
    port=8899
    tag="storage-shared-monitor-dev"
    datadog_label="com.datadoghq.ad.logs='"'[{"source": "arteria_runfolder", "service": "arteria_share_monitor_dev"}]'"'" # composition of 3 strings: ""''"" (to avoid escaping of double quotes in json)
fi

timestamp="$(date +"%Y%m%d%H%M")"
tmpfile=$(mktemp /tmp/app.config.XXXXX)
timestamp_label="TIMESTAMP=$timestamp"

cat > $tmpfile <<- EOF
---
# the directories configured need to reflext the ACTUAL location of the runfolders,
# i.e. if the host path is mounted onto a different container path, then the service
# will not report the correct path and further actions (like rsync) will fail.
monitored_directories:
    - $runfolder_base

can_create_runfolder: False

completed_marker_file: SequenceComplete.txt

state_base_path: /opt/state-folder
EOF


# configure mount points:
# 1. the runfolder base path to monitor
# 2. the folder where to store the state information
# 3. the custom app.config to use
cmd="docker run -d -l $datadog_label -l $timestamp_label --name=$tag --restart=always -p $port:80 -v $runfolder_base:$runfolder_base:ro -v $status_base:/opt/state-folder -v $tmpfile:/opt/runfolder-service/config/app.config umccr/arteria-runfolder-docker:latest"
write_log "INFO: Running: $cmd"
eval "$cmd"

rm $tmpfile
# Test the service with:
# curl localhost:$port/api/1.0/runfolders?state=* | python -m json.tool
