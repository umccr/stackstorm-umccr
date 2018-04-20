#!/bin/bash
# This is configured to monitor /mnt/MDHS-Clinical/Genomics/Baymax and expose it's API on port 8889

runfolder_base="/storage/shared/raw/Baymax"
status_base="/opt/Pipeline/prod/runfolder-status"
port=8888
tag="storage-shared-monitor"
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

# configure two mount points:
# 1. the path to monitor for runfolders
# 2. the app.config used to configure the serivce with that path
docker run -d --name=$tag-$timestamp --rm -p $port:80 \
        -v $runfolder_base:$runfolder_base:ro \
        -v $status_base:/opt/state-folder \
        -v $tmpfile:/opt/runfolder-service/config/app.config \
        umccr/arteria-runfolder-docker:latest

rm $tmpfile
# Test the service with:
# curl localhost:8888/api/1.0/runfolders?state=* | python -m json.tool
