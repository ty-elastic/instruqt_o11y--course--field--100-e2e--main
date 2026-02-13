source assets/scripts/retry.sh

while getopts "h:i:j:k:" opt
do
   case "$opt" in
      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      k ) elasticsearch_otlp_endpoint="$OPTARG" ;;
   esac
done

assets/scripts/dashboards.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
assets/scripts/integrations.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
