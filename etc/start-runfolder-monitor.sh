#!/bin/bash

runfolder_base="/storage/shared/dev/Baymax"
status_base="/opt/Pipeline/dev/runfolder-status"
port=8899
tag="storage-shared-monitor-dev"
timestamp="$(date +"%Y%m%d%H%M")"

tmpfile=$(mktemp /tmp/app.config.XXXXX)

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

# TODO: log execution

# configure mount points:
# 1. the runfolder to monitor
# 2. the folder where to store the state information
# 3. the custom app.config to use
docker run -d --name=$tag-$timestamp --rm -p $port:80 \
        -v $runfolder_base:$runfolder_base:ro \
        -v $status_base:/opt/state-folder \
        -v $tmpfile:/opt/runfolder-service/config/app.config \
        umccr/arteria-runfolder-docker:latest

rm $tmpfile
# Test the service with:
# curl localhost:8899/api/1.0/runfolders?state=* | python -m json.tool
