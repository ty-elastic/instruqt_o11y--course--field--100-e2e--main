source /workspace/workshop/instruqt/scripts/vars.sh

echo "Configuring GenAI"
output=$(curl -X POST -s -u "admin:${ELASTICSEARCH_PASSWORD}" \
  -w "\n%{http_code}" \
  $KIBANA_URL/internal/kibana/settings \
  -H 'Content-Type: application/json' \
  -H "kbn-xsrf: true" \
  -H 'x-elastic-internal-origin: Kibana' \
  -d '{"changes":{"aiAssistant:preferredChatExperience": "agent"}}')
