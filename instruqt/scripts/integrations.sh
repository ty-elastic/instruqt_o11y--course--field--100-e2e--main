source /workspace/workshop/instruqt/scripts/retry.sh

echo "Configuring Fleet"
output=$(curl -X PUT -s -u "admin:${ELASTICSEARCH_PASSWORD}" \
  -w "\n%{http_code}" \
  $KIBANA_URL/api/fleet/settings \
  -H 'Content-Type: application/json' \
  -H "kbn-xsrf: true" \
  -d '{"prerelease_integrations_enabled": true}')
