#!/bin/bash

WORKING_DIR=/root/workshop
source $WORKING_DIR/instruqt/scripts/retry.sh

export DEPLOYMENT_ID=`agent variable get ES_DEPLOYMENT_ID`
export ES3_API_PY=$WORKING_DIR/instruqt/scripts/serverless/es3-api.py

printf "Cleaning up project $PROJECT_TYPE $DEPLOYMENT_ID in $REGIONS...\n"

python3 $ES3_API_PY \
   --operation delete \
   --project-type $PROJECT_TYPE \
   --regions $REGIONS \
   --project-id $DEPLOYMENT_ID \
   --api-key $ESS_CLOUD_API_KEY

printf "Cleaning up project $PROJECT_TYPE $DEPLOYMENT_ID in $REGIONS...SUCCESS\n"
