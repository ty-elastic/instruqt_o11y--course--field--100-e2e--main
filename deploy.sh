course=latest
service=all
local=false
variant=none
otel=false
namespace=trading
region=1

postgresql_host=postgresql
postgresql_user=admin
postgresql_password=password
postgresql_sslmode=disable

while getopts "l:c:s:v:o:n:r:g:h:i:j:" opt
do
   case "$opt" in
      c ) course="$OPTARG" ;;
      s ) service="$OPTARG" ;;
      l ) local="$OPTARG" ;;
      v ) variant="$OPTARG" ;;
      o ) otel="$OPTARG" ;;
      n ) namespace="$OPTARG" ;;
      r ) region="$OPTARG" ;;
      g ) postgresql_host="$OPTARG" ;;
      h ) postgresql_user="$OPTARG" ;;
      i ) postgresql_password="$OPTARG" ;;
      j ) postgresql_sslmode="$OPTARG" ;;
   esac
done

repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
if [ "$local" = "true" ]; then
    repo=localhost:5093
fi

export COURSE=$course
export REPO=$repo
export NAMESPACE=$namespace
export REGION=$region

export POSTGRESQL_HOST=$postgresql_host
export POSTGRESQL_USER=$postgresql_user
export POSTGRESQL_PASSWORD=$postgresql_password
export POSTGRESQL_SSLMODE=$postgresql_sslmode

if [ "$otel" != "false" ]; then
    # ---------- COLLECTOR

    echo "values-$otel.yaml"

    cd collector
    helm upgrade --install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack \
    --namespace opentelemetry-operator-system \
    --values "values-$otel.yaml" \
    --version '0.9.1'
    cd ..

    sleep 30
fi

envsubst < k8s/yaml/_namespace.yaml | kubectl apply -f -

if [ "$service" != "none" ]; then
    for file in k8s/yaml/*.yaml; do
        current_service=$(basename "$file")
        current_service="${current_service%.*}"
        echo $current_service
        echo $service
        echo $REGION
        if [[ "$service" == "all" || "$service" == "$current_service" ]]; then
            echo "deploying..."
            envsubst < k8s/yaml/$current_service.yaml | kubectl apply -f -
            kubectl -n $namespace rollout restart deployment/$current_service
        fi
    done
fi
