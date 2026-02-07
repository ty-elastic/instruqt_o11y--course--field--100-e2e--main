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

config_profiling_agent() {
    echo -e "enabling profiling\n"
    kubectl apply -f agents/profiling/profiler.yaml
}
config_profiling_agent

config_profiling() {
    echo "top"

    output=$(curl -s -X GET "$elasticsearch_kibana_endpoint/api/fleet/epm/packages" \
        -w "\n%{http_code}" \
        -H 'kbn-xsrf: true' \
        -H "Authorization: ApiKey ${elasticsearch_api_key}")

    # Extract HTTP status code and response body
    fleet_http_code=$(echo "$output" | tail -n1)
    fleet_response=$(echo "$output" | sed '$d')

    # Check if the Fleet API call was successful
    if [ "$fleet_http_code" != "200" ]; then
      echo "Warning: Failed to fetch integrations: $fleet_http_code"
      echo "Response: $fleet_response"
      return 1
    fi

    echo "fleet packages: $fleet_http_code"

    PROFILING_PACKAGE=$(echo $fleet_response | jq -r '.items[] | select (.name == "profilingmetrics_otel")')
    PROFILING_PACKAGE_NAME=$(echo $PROFILING_PACKAGE | jq -r '.name')
    PROFILING_PACKAGE_VERSION=$(echo $PROFILING_PACKAGE | jq -r '.version')
    echo $PROFILING_PACKAGE_NAME
    echo $PROFILING_PACKAGE_VERSION

    echo "here"
    
    if [[ -z "$PROFILING_PACKAGE_NAME" ]]; then
        echo "PROFILING_PACKAGE_NAME is unset"
        return 1
    fi

    echo "here3"

    output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/api/fleet/epm/packages/$PROFILING_PACKAGE_NAME/$PROFILING_PACKAGE_VERSION" \
        -w "\n%{http_code}" \
        -H 'kbn-xsrf: true' \
        -H "Authorization: ApiKey ${elasticsearch_api_key}")
    echo $output

    fleet_http_code=$(echo "$output" | tail -n1)
    fleet_response=$(echo "$output" | sed '$d')

    if [ "$fleet_http_code" != "200" ]; then
        echo "Warning: Failed to fetch integrations: $fleet_response"
        echo "Response: $fleet_response"
        return 1
    fi

    DASHBOARD=$(echo $output | jq -r '.items[] | select (.type == "dashboard")')
    DASHBOARD_ID=$(echo $DASHBOARD | jq -r '.id')
    echo $DASHBOARD_ID

    echo -e "Set custom dashboard\n"
    curl -X POST "$elasticsearch_kibana_endpoint/api/infra/host/custom-dashboards" \
        -H 'kbn-xsrf: true' \
        -H 'x-elastic-internal-origin: Kibana' \
        -H "Authorization: ApiKey ${elasticsearch_api_key}" \
        -H 'Content-Type: application/json' \
        -d '{"dashboardSavedObjectId": "'$DASHBOARD_ID'", "dashboardFilterAssetIdEnabled":true}'

    return 0
}
retry_command_lin config_profiling
