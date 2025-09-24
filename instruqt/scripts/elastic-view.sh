source /opt/workshops/elastic-retry.sh
export $(curl http://kubernetes-vm:9000/env | xargs)

/opt/workshops/elastic-view.sh -v oblt

echo "Hide tour"
hide_tour() {
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KIBANA_URL/internal/kibana/settings" \
    --header 'Content-Type: application/json' \
    --header "kbn-xsrf: true" \
    --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
    --header 'x-elastic-internal-origin: Kibana' \
    -d '{"changes":{"hideAnnouncements":true}}')

    if echo $http_status | grep -q '^2'; then
        echo "Disabled Tour: $http_status"
        return 0
    else
        echo "Failed to disable Tour. HTTP status: $http_status"
        return 1
    fi
}
retry_command_lin hide_tour
