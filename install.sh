#!/bin/bash

# es bootstrap
./build.sh -o false -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL -f true

# infra
./build.sh -t $FLEET_URL -c $COURSE -1 true -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL

# services
./build.sh -o serverless -t $FLEET_URL -c $COURSE -d true -n true -b false -s all -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL

# synthetics, profiling
./build.sh -o false -t $FLEET_URL -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL -p true -m true

# assets
./build.sh -o false -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL -w true

# grafana
./build.sh -o false -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $INGEST_URL -g true
