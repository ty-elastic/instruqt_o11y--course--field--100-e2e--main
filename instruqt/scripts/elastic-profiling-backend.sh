source /opt/workshops/elastic-retry.sh
export $(curl http://kubernetes-vm:9000/env | xargs)

# ------------- APIKEY

output=$(curl -s -X POST --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64"  -H 'Content-Type: application/json' "$ELASTICSEARCH_URL/_security/api_key" -d '
{
    "name": "profiling",
    "expiration": "7d",
    "role_descriptors": {
        "profiling": {
            "cluster": [
                "monitor"
            ],
            "indices": [
                {
                    "names": [
                        "profiling-*"
                    ],
                    "privileges": [
                        "read",
                        "write"
                    ]
                }
            ]
        }
    }
}
')
export PROFILING_APIKEY=$(echo $output | jq -r '.encoded')

cd /workspace/workshop

envsubst < profiling/collector.yml > profiling/collector-rendered.yml
envsubst < profiling/symbolizer.yml > profiling/symbolizer-rendered.yml

kubectl patch Kibana kibana -p '{"spec": {"config": {"xpack.profiling.enabled": true}}}' --type=merge

podman run -d --net host --name pf-elastic-collector -p 8260:8260 -v profiling/collector-rendered.yml:/pf-elastic-collector.yml:ro docker.elastic.co/observability/profiling-collector:9.2.2 -c /pf-elastic-collector.yml

podman run -d --net host --name pf-elastic-symbolizer -p 8240:8240 -v profiling/symbolizer-rendered.yml:/pf-elastic-symbolizer.yml:ro docker.elastic.co/observability/profiling-symbolizer:9.2.2 -c /pf-elastic-symbolizer.yml
