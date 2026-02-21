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
    echo -e "Configuring APM Dataview\n"
    curl -X POST "$elasticsearch_kibana_endpoint/internal/apm/data_view/static" \
        -H 'kbn-xsrf: true' \
        -H 'x-elastic-internal-origin: Kibana' \
        -H "Authorization: ApiKey ${elasticsearch_api_key}"
}

#config_apm_ml
config_apm_dv
