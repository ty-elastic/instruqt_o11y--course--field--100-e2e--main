source /opt/workshops/elastic-retry.sh
export $(curl http://kubernetes-vm:9000/env | xargs)

if [[ ! -v LLM_MODEL_ID ]]; then
    echo "LLM_MODEL_ID not set, defaulting to gpt-4.1"
    LLM_MODEL_ID="gpt-4.1"
else
    echo "LLM_MODEL_ID=$LLM_MODEL_ID"
fi

/opt/workshops/elastic-llm.sh -m $LLM_MODEL_ID -k true -d true -p false 

# -------------

echo "Initializing AI Assistant Everywhere"
init_ai_everywhere() {
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$KIBANA_URL/internal/kibana/settings" \
    --header 'Content-Type: application/json' \
    --header "kbn-xsrf: true" \
    --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
    --header 'x-elastic-internal-origin: Kibana' \
    -d '{"changes":{"aiAssistant:preferredAIAssistantType":"observability"}}')

    if echo $http_status | grep -q '^2'; then
        echo "Elastic AI Assistant Everywhere successfully initialized: $http_status"
        return 0
    else
        echo "Failed to initialize Elastic AI Assistant Everywhere. HTTP status: $http_status"
        return 1
    fi
}
retry_command_lin init_ai_everywhere

# -------------

echo "Adding completion connector"
add_connector() {
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$ELASTICSEARCH_URL/_inference/completion/openai_completion" \
    --header 'Content-Type: application/json' \
    --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" -d'
    {
        "service": "openai",
        "service_settings": {
            "model_id": "'"$LLM_MODEL_ID"'",
            "api_key": "'"$LLM_APIKEY"'",
            "url": "https://'"$LLM_PROXY_URL"'/v1/chat/completions"
        }
    }')

    if echo $http_status | grep -q '^2'; then
        echo "Connector added successfully with HTTP status: $http_status"
        return 0
    else
        echo "Failed to add connector. HTTP status: $http_status"
        return 1
    fi
}
retry_command_lin add_connector
