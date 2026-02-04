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

config_integrations() {
  echo -e "Configuring Fleet\n"
  curl -X PUT "$elasticsearch_kibana_endpoint/api/fleet/settings" \
      -H 'Content-Type: application/json' \
      -H 'kbn-xsrf: true' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'x-elastic-internal-origin: Kibana' \
      -d '{"prerelease_integrations_enabled": true}'
}
config_integrations
