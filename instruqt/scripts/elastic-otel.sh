source /opt/workshops/elastic-retry.sh
export $(curl http://kubernetes-vm:9000/env | xargs)

namespace=opentelemetry-operator-system
while getopts "n:" opt
do
   case "$opt" in
      n ) namespace="$OPTARG" ;;
   esac
done

output=$(curl -s -X POST --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64"  -H 'Content-Type: application/json' "$ELASTICSEARCH_URL/_security/api_key" -d '
{
    "name": "kubernetes_otel_onboarding",
    "metadata": {
        "application": "logs",
        "managed": true
    },
    "role_descriptors": {
        "standalone_agent": {
            "cluster": [
            "monitor"
            ],
            "indices": [
            {
                "names": [
                "logs-*-*",
                "metrics-*-*",
                "traces-*-*"
                ],
                "privileges": [
                "auto_configure",
                "create_doc"
                ],
                "allow_restricted_indices": false
            }
            ],
            "applications": [],
            "run_as": [],
            "metadata": {},
            "transient_metadata": {
            "enabled": true
            }
        }
    }
}
')

ELASTICSEARCH_APIKEY=$(echo $output | jq -r '.encoded')

helm repo add open-telemetry 'https://open-telemetry.github.io/opentelemetry-helm-charts' --force-update

kubectl create namespace $namespace
kubectl create secret generic elastic-secret-otel \
  --namespace $namespace \
  --from-literal=elastic_endpoint=$ELASTICSEARCH_URL \
  --from-literal=elastic_api_key=$ELASTICSEARCH_APIKEY
