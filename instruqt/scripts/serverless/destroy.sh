#!/bin/bash

export DEPLOYMENT_ID=`agent variable get ES_DEPLOYMENT_ID`

printf "Cleaning up project $PROJECT_TYPE $DEPLOYMENT_ID in $REGIONS...\n"

python3 ~/bin/es3-api.py \
   --operation delete \
   --project-type $PROJECT_TYPE \
   --regions $REGIONS \
   --project-id $DEPLOYMENT_ID \
   --api-key $ESS_CLOUD_API_KEY

printf "Cleaning up project $PROJECT_TYPE $DEPLOYMENT_ID in $REGIONS...SUCCESS\n"
