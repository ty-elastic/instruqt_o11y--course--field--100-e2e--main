#!/bin/bash

source $PWD/assets/scripts/retry.sh
source $PWD/assets/scripts/integration_packages.sh

OPTIND=1
while getopts "n:h:i:j:k:" opt
do
   case "$opt" in
      n ) namespace="$OPTARG" ;;

      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      k ) elasticsearch_otlp_endpoint="$OPTARG" ;;
   esac
done

install_integration_package "profilingmetrics_otel" $elasticsearch_kibana_endpoint $elasticsearch_api_key
