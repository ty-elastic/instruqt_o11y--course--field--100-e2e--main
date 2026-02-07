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
    printf "$FUNCNAME...\n"
    kubectl apply -f agents/profiling/profiler.yaml
    printf "$FUNCNAME...SUCCESS\n"
}
config_profiling_agent

config_profiling() {
    printf "$FUNCNAME...\n"

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

    PROFILING_PACKAGE=$(echo $http_response | jq -r '.items[] | select (.name == "profilingmetrics_otel")')
    PROFILING_PACKAGE_NAME=$(echo $PROFILING_PACKAGE | jq -r '.name')
    PROFILING_PACKAGE_VERSION=$(echo $PROFILING_PACKAGE | jq -r '.version')
    # echo $PROFILING_PACKAGE_NAME
    # echo $PROFILING_PACKAGE_VERSION

    if [[ -z "$PROFILING_PACKAGE_NAME" ]]; then
        printf "$FUNCNAME...ERROR: PROFILING_PACKAGE_NAME is unset\n"
        return 1
    fi
    printf "$FUNCNAME...PROFILING_PACKAGE_NAME=$PROFILING_PACKAGE_NAME, PROFILING_PACKAGE_VERSION=$PROFILING_PACKAGE_VERSION\n"

    output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/api/fleet/epm/packages/$PROFILING_PACKAGE_NAME/$PROFILING_PACKAGE_VERSION" \
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

    DASHBOARD=$(echo $http_response | jq -r '.items[] | select (.type == "dashboard")')
    DASHBOARD_ID=$(echo $DASHBOARD | jq -r '.id')

    printf "$FUNCNAME...DASHBOARD_ID=$DASHBOARD_ID\n"

    output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/api/infra/host/custom-dashboards" \
        -w "\n%{http_code}" \
        -H 'kbn-xsrf: true' \
        -H 'x-elastic-internal-origin: Kibana' \
        -H "Authorization: ApiKey ${elasticsearch_api_key}" \
        -H 'Content-Type: application/json' \
        -d '{"dashboardSavedObjectId": "'$DASHBOARD_ID'", "dashboardFilterAssetIdEnabled":true}')

    # Extract HTTP status code
    http_code=$(echo "$output" | tail -n1)
    http_response=$(echo "$output" | sed '$d')
    if [ "$http_code" != "200" ]; then
        printf "$FUNCNAME...ERROR $http_code: $http_response\n"
        #return 1
    fi

    printf "$FUNCNAME...SUCCESS\n"
    return 0
}
retry_command_lin config_profiling
