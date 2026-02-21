source assets/scripts/retry.sh

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

config_apm_ml() {
    echo -e "Configuring APM ML\n"
    curl -X POST "$elasticsearch_kibana_endpoint/internal/apm/settings/anomaly-detection/jobs" \
        -H 'Content-Type: application/json' \
        -H 'kbn-xsrf: true' \
        -H 'x-elastic-internal-origin: Kibana' \
        -H "Authorization: ApiKey ${elasticsearch_api_key}" \
        -d '{"environments":["'$namespace'"]}'
}

config_apm_dv() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/internal/apm/data_view/static" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}")

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

# hardcode for setup speed, but need to update regularly
RUM_PACKAGE_NAME=otel_rum_dashboards
RUM_PACKAGE_VERSION=0.0.1

config_rum() {
    printf "$FUNCNAME...\n"

    if [[ -z "$RUM_PACKAGE_NAME" ]]; then
        output=$(curl -s -X GET "$elasticsearch_kibana_endpoint/api/fleet/epm/packages" \
            -w "\n%{http_code}" \
            -H 'kbn-xsrf: true' \
            -H 'x-elastic-internal-origin: Kibana' \
            -H "Authorization: ApiKey ${elasticsearch_api_key}")

        # Extract HTTP status code
        http_code=$(echo "$output" | tail -n1)
        http_response=$(echo "$output" | sed '$d')
        if [ "$http_code" != "200" ]; then
            printf "$FUNCNAME...ERROR $http_code: $http_response\n"
            return 1
        fi

        RUM_PACKAGE=$(echo $http_response | jq -r '.items[] | select (.name == "otel_rum_dashboards")')
        RUM_PACKAGE_NAME=$(echo $RUM_PACKAGE | jq -r '.name')
        RUM_PACKAGE_VERSION=$(echo $RUM_PACKAGE | jq -r '.version')

        if [[ -z "$RUM_PACKAGE_NAME" ]]; then
            printf "$FUNCNAME...ERROR: RUM_PACKAGE_NAME is unset\n"
            return 1
        fi
        printf "$FUNCNAME...RUM_PACKAGE_NAME=$RUM_PACKAGE_NAME, RUM_PACKAGE_VERSION=$RUM_PACKAGE_VERSION\n"
    fi
    
    output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/api/fleet/epm/packages/$RUM_PACKAGE_NAME/$RUM_PACKAGE_VERSION" \
        -w "\n%{http_code}" \
        -H 'kbn-xsrf: true' \
        -H 'x-elastic-internal-origin: Kibana' \
        -H "Authorization: ApiKey ${elasticsearch_api_key}")

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


#config_apm_ml
retry_command_lin config_apm_dv

retry_command_lin config_rum
