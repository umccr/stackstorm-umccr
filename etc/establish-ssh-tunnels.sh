#!/bin/bash
set -e

if test -z "$DEPLOY_ENV"; then
    echo "DEPLOY_ENV is not set! Set it to either 'dev' or 'prod'."
    exit 1
fi

# create a tunnel for the arteria runfolder service on port 8888 and
# for general ssh access (novastor ssh is configured for port 4321)
if test "$DEPLOY_ENV" = "prod"; then
    autossh -M 30000 -f -N -R 8888:0.0.0.0:8888 ubuntu@stackstorm.prod.umccr.org &
    autossh -M 31000 -f -N -R 2222:0.0.0.0:4321 ubuntu@stackstorm.prod.umccr.org &
else
    autossh -M 40000 -f -N -R 8888:0.0.0.0:8899 ubuntu@stackstorm.dev.umccr.org &
    autossh -M 41000 -f -N -R 2222:0.0.0.0:4321 ubuntu@stackstorm.dev.umccr.org &
fi
