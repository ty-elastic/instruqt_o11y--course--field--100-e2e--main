source /opt/workshops/elastic-retry.sh
export $(curl http://kubernetes-vm:9000/env | xargs)

# ------------- STREAMS

echo "/api/streams/_enable"
curl -X POST "$KIBANA_URL/api/streams/_enable" \
    --header "kbn-xsrf: true" \
    --header 'x-elastic-internal-origin: Kibana' \
    --header "Authorization: ApiKey $ELASTICSEARCH_APIKEY"

echo "/internal/kibana/settings"
curl -X POST "$KIBANA_URL/internal/kibana/settings" \
    --header 'Content-Type: application/json' \
    --header "kbn-xsrf: true" \
    --header "Authorization: ApiKey $ELASTICSEARCH_APIKEY" \
    --header 'x-elastic-internal-origin: Kibana' \
    -d '{"changes":{"observability:streamsEnableSignificantEvents":true}}'

# ------------- DATAVIEW

echo "/api/data_views/data_view"
curl -X POST "$KIBANA_URL/api/data_views/data_view" \
    --header 'Content-Type: application/json' \
    --header "kbn-xsrf: true" \
    --header "Authorization: ApiKey $ELASTICSEARCH_APIKEY" \
    -d '
{
  "data_view": {
    "name": "logs-wired",
    "title": "logs.*,logs"
  }
}'