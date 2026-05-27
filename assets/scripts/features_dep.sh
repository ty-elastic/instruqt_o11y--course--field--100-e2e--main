#!/bin/bash

source $PWD/assets/scripts/retry.sh

OPTIND=1
while getopts "h:i:j:k:" opt
do
   case "$opt" in
      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      k ) elasticsearch_otlp_endpoint="$OPTARG" ;;
   esac
done

source $PWD/assets/scripts/apm.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
source $PWD/assets/scripts/dashboards.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
source $PWD/assets/scripts/integrations.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint

hide_announcements() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/internal/kibana/global_settings" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{"changes":{"hideAnnouncements":true}}')

   # Extract HTTP status code
   http_code=$(echo "$output" | tail -n1)
   http_response=$(echo "$output" | sed '$d')
   if [ "$http_code" != "200" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi
   printf "$FUNCNAME...SUCCESS\n"
   return 0
}
hide_announcements
