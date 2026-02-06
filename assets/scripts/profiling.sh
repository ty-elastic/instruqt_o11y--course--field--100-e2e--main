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

config_profiling() {
    echo -e "enabling profiling\n"
    kubectl apply -f agents/profiling/profiler.yaml

    echo -e "Configuring custom dashboards\n"
    curl -X POST "$elasticsearch_kibana_endpoint/internal/kibana/settings" \
        -H 'kbn-xsrf: true' \
        -H 'x-elastic-internal-origin: Kibana' \
        -H "Authorization: ApiKey ${elasticsearch_api_key}" \
        -H 'Content-Type: application/json' \
        -d '{"changes":{"observability:enableInfrastructureAssetCustomDashboards": true}}'

    output=$(curl -s -X GET "$elasticsearch_kibana_endpoint/api/fleet/epm/packages" \
        -H 'kbn-xsrf: true' \
        -H "Authorization: ApiKey ${elasticsearch_api_key}")

    PROFILING_PACKAGE=$(echo $output | jq -r '.items[] | select (.name == "profilingmetrics_otel")')
    PROFILING_PACKAGE_NAME=$(echo $PROFILING_PACKAGE | jq -r '.name')
    PROFILING_PACKAGE_VERSION=$(echo $PROFILING_PACKAGE | jq -r '.version')
    echo $PROFILING_PACKAGE_NAME
    echo $PROFILING_PACKAGE_VERSION

    output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/api/fleet/epm/packages/$PROFILING_PACKAGE_NAME/$PROFILING_PACKAGE_VERSION" \
        -H 'kbn-xsrf: true' \
        -H "Authorization: ApiKey ${elasticsearch_api_key}")
    echo $output

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
}
config_profiling
