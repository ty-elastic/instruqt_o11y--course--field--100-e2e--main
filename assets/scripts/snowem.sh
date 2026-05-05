#!/bin/bash

source $PWD/assets/scripts/retry.sh

while getopts "h:i:e:" opt
do
   case "$opt" in

      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      e ) remote_endpoint="$OPTARG" ;;
   esac
done

create_snowem_connector() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/api/actions/connector/snowem" \
         -w "\n%{http_code}" \
         -H 'kbn-xsrf: true' \
         -H 'x-elastic-internal-origin: Kibana' \
         -H "Authorization: ApiKey ${elasticsearch_api_key}" \
         -H 'Content-Type: application/json' \
         -d '{
         "name":"snowem",
         "config":{"usesTableApi":false,"apiUrl":"'$remote_endpoint'","isOAuth":false},
         "secrets":{"username":"admin","password":"admin"},
         "connector_type_id":".servicenow"
    }')

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
retry_command_lin create_snowem_connector
