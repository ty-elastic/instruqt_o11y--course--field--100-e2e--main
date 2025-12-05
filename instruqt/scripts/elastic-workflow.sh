source /opt/workshops/elastic-retry.sh
export $(curl http://kubernetes-vm:9000/env | xargs)

# ------------- ENABLE ONE WORKFLOW

echo "Initializing OneWorkflow"
init_one_workflow() {
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KIBANA_URL/internal/kibana/settings" \
    --header 'Content-Type: application/json' \
    --header "kbn-xsrf: true" \
    --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
    --header 'x-elastic-internal-origin: Kibana' \
    -d '{"changes":{"workflows:ui:enabled":true}}')

    if echo $http_status | grep -q '^2'; then
        echo "OneWorkflow successfully initialized: $http_status"
        return 0
    else
        echo "Failed to initialize OneWorkflow. HTTP status: $http_status"
        return 1
    fi
}
retry_command_lin init_one_workflow

