#!/bin/bash

# create a tunnel for the arteria runfolder service on port 8888
autossh -M 30000 -f -N -R 8888:0.0.0.0:8888 ubuntu@stackstorm.prod.umccr.org &

# create a tunnel for general ssh access (novastor ssh is configured for port 4321)
autossh -M 31000 -f -N -R 2222:0.0.0.0:4321 ubuntu@stackstorm.prod.umccr.org &
