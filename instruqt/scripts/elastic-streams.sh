source /opt/workshops/elastic-retry.sh
export $(curl http://kubernetes-vm:9000/env | xargs)

echo "Enable Streams"
enable_streams() {
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KIBANA_URL/api/streams/_enable" \
    --header 'Content-Type: application/json' \
    --header "kbn-xsrf: true" \
    --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
    --header 'x-elastic-internal-origin: Kibana')

    if echo $http_status | grep -q '^2'; then
        echo "Enabled Streams: $http_status"
        return 0
    else
        echo "Failed to enable Streams. HTTP status: $http_status"
        return 1
    fi
}
retry_command_lin enable_streams

# ------------- INDEX

index_orig=$(curl -s -X GET "$ELASTICSEARCH_URL/_component_template/logs@settings?flat_settings=true" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64")

index_orig_strip=$(echo $index_orig | jq --compact-output -r '.component_templates[0].component_template')

echo $index_orig_strip | jq --compact-output -r '.template.settings["index.refresh_interval"]="1s"' > index_new.json

index_new_put=$(curl -s -X PUT "$ELASTICSEARCH_URL/_component_template/logs@settings" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
    -d @index_new.json)

echo $index_new_put

# ------------- MAPPING

map_orig=$(curl -s -X GET "$ELASTICSEARCH_URL/_component_template/otel@mappings?flat_settings=true" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64")

map_orig_strip=$(echo $map_orig | jq --compact-output -r '.component_templates[0].component_template')

echo $map_orig_strip | sed 's|{"template":{"mappings":{"dynamic":false|{"template":{"mappings":{"dynamic":true|' > map_new.json

map_new_put=$(curl -s -X PUT "$ELASTICSEARCH_URL/_component_template/otel@mappings" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
    -d @map_new.json)

echo $map_new_put

# ------------- DATAVIEWS

echo "Disable field caching"
disable_field_caching() {
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KIBANA_URL/internal/kibana/settings" \
    --header 'Content-Type: application/json' \
    --header "kbn-xsrf: true" \
    --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
    --header 'x-elastic-internal-origin: Kibana' \
    -d '{"changes":{"data_views:cache_max_age":0}}')

    if echo $http_status | grep -q '^2'; then
        echo "Disabled field caching: $http_status"
        return 0
    else
        echo "Failed to disable field caching. HTTP status: $http_status"
        return 1
    fi
}
retry_command_lin disable_field_caching

