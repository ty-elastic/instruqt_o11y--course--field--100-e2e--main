retry_command_lin() {
    local max_attempts=256
    local timeout=2
    local attempt=1
    local exit_code=0

    while [ $attempt -le $max_attempts ]
    do
        "$@"
        exit_code=$?

        if [ $exit_code -eq 0 ]; then
            break
        fi

        echo "Attempt $attempt failed! Retrying in $timeout seconds..."
        sleep $timeout
        attempt=$(( attempt + 1 ))
    done

    if [ $exit_code -ne 0 ]; then
        echo "Command $@ failed after $attempt attempts!"
    fi

    return $exit_code
}

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

check_assets() {
    kubectl wait --for=condition=complete job/assets-$1 --timeout=120s
}

notifier_endpoint=""

arch=linux/amd64
course=latest
service=all
local=false
namespace_base=trading
region=1
service_version="1.0"
assets=false
profiling=false

build_service=false
build_lib=false
deploy_otel=false
deploy_service=false
annotations=true

elasticsearch_es_endpoint="na"
elasticsearch_kibana_endpoint="na"
elasticsearch_api_key="na"
elasticsearch_otlp_endpoint="na"

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    *)          machine="UNKNOWN:${unameOut}"
esac

while getopts "a:c:s:l:b:x:o:d:r:v:g:h:i:j:k:w:y:p:" opt
do
   case "$opt" in
      a ) arch="$OPTARG" ;;
      c ) course="$OPTARG" ;;
      s ) service="$OPTARG" ;;
      l ) local="$OPTARG" ;;

      b ) build_service="$OPTARG" ;;
      x ) build_lib="$OPTARG" ;;
      o ) deploy_otel="$OPTARG" ;;
      d ) deploy_service="$OPTARG" ;;

      r ) region="$OPTARG" ;;
      v ) service_version="$OPTARG" ;;

      p ) profiling="$OPTARG" ;;

      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      k ) elasticsearch_otlp_endpoint="$OPTARG" ;;

      w ) assets="$OPTARG" ;;
      y ) annotations="$OPTARG" ;;
   esac
done

export MSSQL_HOST=mssql
export MSSQL_USER=sa
export MSSQL_PASSWORD=Pa55w0rd2019
export MSSQL_DBNAME=trades
export MSSQL_PORT=1433
export MSSQL_PROTOCOL=sqlserver
export MSSQL_SETUP=none
export MSSQL_OPTIONS=";Database=trades;Integrated Security=false;Encrypt=false;TrustServerCertificate=true"
export MSSQL_DIALECT="SQLServerDialect"

export POSTGRESQL_HOST=postgresql
export POSTGRESQL_USER=postgres
export POSTGRESQL_PASSWORD=postgres
export POSTGRESQL_DBNAME=postgres
export POSTGRESQL_PROTOCOL=postgresql
export POSTGRESQL_SETUP=none
export POSTGRESQL_OPTIONS="/postgres?sslmode=disable"
export POSTGRESQL_PORT=5432
export POSTGRESQL_DIALECT=PostgreSQLDialect

# Save the original IFS to restore it later
OIFS="$IFS"
# Set IFS to the comma delimiter
IFS=","
# Create the array from the string
regions=($region)
# Restore the original IFS
IFS="$OIFS"

if [ -f ".env" ]; then
    set -o allexport # Automatically export all variables defined after this point
    source .env
    set +o allexport # Stop automatic exporting
fi

for current_region in "${regions[@]}"; do
    echo "setup for region=$current_region"

    namespace=$namespace_base-$current_region
    echo $namespace

    repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
    if [ "$local" = "true" ]; then
        docker run -d -p 5093:5000 --restart=always --name registry registry:2
        repo=localhost:5093
    else
        if [[ "$build_service" == "true" || "$build_lib" == "true" ]]; then
            gcloud auth configure-docker us-central1-docker.pkg.dev
        fi
    fi

    if [ "$build_service" = "true" ]; then
        cd ./src
        ./build.sh -k $service_version -r $repo -s $service -c $course -a $arch -n $namespace
        cd ..
    fi

    if [ "$build_lib" = "true" ]; then
        cd ./lib
        ./build.sh -r $repo -c $course -a $arch
        cd ..
    fi

    if [ "$deploy_otel" != "false" ]; then
        # ---------- COLLECTOR
        if [ "$deploy_otel" = "true" ]; then
            deploy_otel="stack"
        fi

        echo "deploying $deploy_otel.yaml"

        helm repo add open-telemetry 'https://open-telemetry.github.io/opentelemetry-helm-charts' --force-update

        kubectl create namespace opentelemetry-operator-system

        kubectl --namespace opentelemetry-operator-system delete secret generic elastic-secret-otel
        kubectl create secret generic elastic-secret-otel \
            --namespace opentelemetry-operator-system \
            --from-literal=elastic_otlp_endpoint="$elasticsearch_otlp_endpoint" \
            --from-literal=elastic_endpoint="$elasticsearch_es_endpoint" \
            --from-literal=elastic_api_key="$elasticsearch_api_key"

        cd agents/collector
        helm upgrade --install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack \
        --namespace opentelemetry-operator-system \
        --values "$deploy_otel.yaml" \
        --version '0.12.4'
        cd ../..

        kubectl -n opentelemetry-operator-system rollout restart deployment
        #sleep 30
    fi

    if [[ "$deploy_service" == "true" || "$deploy_service" == "delete" || "$deploy_service" == "force" ]]; then
        export COURSE=$course
        export REPO=$repo
        export NAMESPACE=$namespace
        export REGION=$current_region

        export SERVICE_VERSION=$service_version
        export NOTIFIER_ENDPOINT=$notifier_endpoint

        export JOB_ID=$(( $RANDOM ))
        echo $JOB_ID

        envsubst < k8s/yaml/_namespace.yaml | kubectl apply -f -

        if [ "$service" != "none" ]; then
            for file in k8s/yaml/*.yaml; do
                current_service=$(basename "$file")
                current_service="${current_service%.*}"

                if [[ "$service" == "all" || "$service" == "$current_service" ]]; then
                    if [ "$deploy_service" = "delete" ]; then
                        echo "deleting $current_service from region $REGION"
                        envsubst < k8s/yaml/$current_service.yaml | kubectl delete -f -
                    else
                        echo "deploying $current_service to region $REGION"
                        envsubst < k8s/yaml/$current_service.yaml | kubectl apply -f -
                        if [ "$deploy_service" = "force" ]; then
                            kubectl -n $namespace rollout restart deployment/$current_service
                        fi

                        if [ "$annotations" = "true" ]; then
                            echo "adding deployment annotation"
                            if [ "$machine" == "Mac" ]; then
                                ts=$(date -z utc +%FT%TZ)
                            elif [ "$machine" == "Linux" ]; then
                                ts=$(date --utc +%FT%TZ)
                            fi
                            curl -X POST "$elasticsearch_kibana_endpoint/api/apm/services/$current_service/annotation" \
                                -H 'Content-Type: application/json' \
                                -H 'kbn-xsrf: true' \
                                -H "Authorization: ApiKey ${elasticsearch_api_key}" \
                                -d '{
                                    "@timestamp": "'$ts'",
                                    "service": {
                                        "environment": "'$namespace'",
                                        "version": "'$SERVICE_VERSION'"
                                    },
                                    "message": "service_deployment='$SERVICE_VERSION'"
                                }'
                        fi
                    fi
                fi
            done
        fi
    fi

    if [ "$deploy_otel" != "false" ]; then
        retry_command_lin check_otel
        echo "restarting deployment"
        kubectl -n $namespace rollout restart deployment
    fi

    if [ "$profiling" = "true" ]; then
        echo "enabling profiling"
        kubectl apply -f agents/collector/profiler.yaml
    fi

    if [ "$assets" = "true" ]; then
        cd assets
        #./build.sh -r $repo -c $course -a $arch
        export COURSE=$course
        export REPO=$repo
        export JOB_ID=$(( $RANDOM ))
        echo $JOB_ID
        export elasticsearch_kibana_endpoint=$elasticsearch_kibana_endpoint
        export elasticsearch_es_endpoint=$elasticsearch_es_endpoint
        export elasticsearch_api_key=$elasticsearch_api_key  
        envsubst < assets.yaml
        envsubst < assets.yaml | kubectl apply -f -
        cd ..

        retry_command_lin check_assets $JOB_ID
    fi

done


