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

config_dashboards() {
    echo -e "Configuring custom dashboards\n"
    curl -X POST "$elasticsearch_kibana_endpoint/internal/kibana/settings" \
        -H 'kbn-xsrf: true' \
        -H 'x-elastic-internal-origin: Kibana' \
        -H "Authorization: ApiKey ${elasticsearch_api_key}" \
        -H 'Content-Type: application/json' \
        -d '{"changes":{"observability:enableInfrastructureAssetCustomDashboards": true}}'
}
config_dashboards
