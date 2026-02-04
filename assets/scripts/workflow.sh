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

config_workflows() {
  echo -e "Configuring Workflows\n"
  curl -X POST "$elasticsearch_kibana_endpoint/internal/kibana/settings" \
      -H 'Content-Type: application/json' \
      -H 'kbn-xsrf: true' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'x-elastic-internal-origin: Kibana' \
      -d '{"changes":{"workflows:ui:enabled":true}}'
}
config_workflows
