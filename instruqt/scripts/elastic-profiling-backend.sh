source /opt/workshops/elastic-retry.sh
export $(curl http://kubernetes-vm:9000/env | xargs)

# ------------- KIBANA

kubectl patch Kibana kibana -p '{"spec": {"config": {"xpack.profiling.enabled": true}}}' --type=merge

echo "/api/profiling/setup/es_resources"
setup_profiling() {
    local http_status=$(curl -s -X POST "$KIBANA_URL/api/profiling/setup/es_resources" \
      --header 'Content-Type: application/json' \
      --header 'x-elastic-internal-origin: Kibana' \
      --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
      --header 'kbn-xsrf: true'
    )

    if echo $http_status | grep -q '^2'; then
        echo "Profiling successfully initialized: $http_status"
        return 0
    else
        echo "Failed to initialize Profiling. HTTP status: $http_status"
        return 1
    fi
}
retry_command_lin setup_profiling

# ------------- SERVICES

output=$(curl -s -X POST --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64"  -H 'Content-Type: application/json' "$ELASTICSEARCH_URL/_security/api_key" -d '
{
    "name": "profiling",
    "expiration": "7d"
}
')
export PROFILING_APIKEY=$(echo $output | jq -r '.encoded')

cd /workspace/workshop/profiling

envsubst < collector.yml > collector-rendered.yml
envsubst < symbolizer.yml > symbolizer-rendered.yml

# podman run -d --net host --name pf-elastic-collector -p 8260:8260 -v $PWD/collector-rendered.yml:/pf-elastic-collector.yml:ro --rm docker.elastic.co/observability/profiling-collector:9.2.2 -c /pf-elastic-collector.yml
# podman run -d --net host --name pf-elastic-symbolizer -p 8240:8240 -v $PWD/symbolizer-rendered.yml:/pf-elastic-symbolizer.yml:ro --rm docker.elastic.co/observability/profiling-symbolizer:9.2.2 -c /pf-elastic-symbolizer.yml
