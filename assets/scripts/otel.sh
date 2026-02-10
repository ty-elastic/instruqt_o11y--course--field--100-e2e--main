source assets/scripts/retry.sh

while getopts "n:h:i:j:k:f:o:" opt
do
   case "$opt" in
      n ) namespace="$OPTARG" ;;

      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      k ) elasticsearch_otlp_endpoint="$OPTARG" ;;

      f) force="$OPTARG" ;;
      o) deploy_otel="$OPTARG" ;;
   esac
done

check_otel() {
    kubectl wait --for=condition=Ready pods --all -n opentelemetry-operator-system --timeout=120s

    if kubectl describe otelinst -n opentelemetry-operator-system | grep -q "No resources found"; then
        echo "otel operator not yet ready"
        return 1
    else
        echo "otel operator ready"
        return 0
    fi
}

deploy_otel() {
    echo "deploying $deploy_otel.yaml"

    helm repo add open-telemetry 'https://open-telemetry.github.io/opentelemetry-helm-charts' --force-update

    kubectl create namespace opentelemetry-operator-system

    kubectl --namespace opentelemetry-operator-system delete secret generic elastic-secret-otel
    kubectl create secret generic elastic-secret-otel \
        --namespace opentelemetry-operator-system \
        --from-literal=elastic_otlp_endpoint="$elasticsearch_otlp_endpoint" \
        --from-literal=elastic_endpoint="$elasticsearch_es_endpoint" \
        --from-literal=elastic_api_key="$elasticsearch_api_key"

    cd agents/apm
    helm upgrade --install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack \
        --namespace opentelemetry-operator-system \
        --values "$deploy_otel.yaml" \
        --version '0.12.4'
    cd ../..

    if [ "$force" = "true" ]; then
        kubectl -n opentelemetry-operator-system rollout restart deployment
    fi
}

deploy_otel
retry_command_lin check_otel
