notifier_endpoint=""

arch=linux/amd64
course=latest
service=all
local=false
namespace_base=trading
region=1
service_version="1.0"

build_service=false
build_lib=false
deploy_otel=false
deploy_service=false

while getopts "a:c:s:l:b:x:o:d:r:v:" opt
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
export POSTGRESQL_DBNAME=trades
export POSTGRESQL_PROTOCOL=postgresql
export POSTGRESQL_SETUP=none
export POSTGRESQL_OPTIONS="/trades?sslmode=disable"
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

for current_region in "${regions[@]}"; do
    echo "setup for region=$current_region"
    
    if [ -f "./.env" ]; then
        export $(cat ./.env | xargs)
    fi

    namespace=$namespace_base-$current_region
    echo $namespace

    repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
    if [ "$local" = "true" ]; then
        docker run -d -p 5093:5000 --restart=always --name registry registry:2
        repo=localhost:5093
    fi

    if [ "$build_service" = "true" ]; then
        cd ./src
        ./build.sh -k $service_version -r $repo -s $service -c $course -a $arch -n $namespace -t $elasticsearch_rum_endpoint -u $elasticsearch_kibana_endpoint -v $elasticsearch_api_key
        cd ..
    fi

    if [ "$build_lib" = "true" ]; then
        cd ./lib
        ./build.sh -r $repo -c $course -a $arch
        cd ..
    fi

    if [ "$deploy_otel" != "false" ]; then
        # ---------- COLLECTOR

        echo "deploying values-$deploy_otel.yaml"

        helm repo add open-telemetry 'https://open-telemetry.github.io/opentelemetry-helm-charts' --force-update

        kubectl --namespace opentelemetry-operator-system delete secret generic elastic-secret-otel
        kubectl create secret generic elastic-secret-otel \
            --namespace opentelemetry-operator-system \
            --from-literal=elastic_endpoint="$elasticsearch_es_endpoint" \
            --from-literal=elastic_api_key="$elasticsearch_api_key"

        cd collector
        helm upgrade --install opentelemetry-kube-stack open-telemetry/opentelemetry-kube-stack \
        --namespace opentelemetry-operator-system \
        --values "values-$deploy_otel.yaml" \
        --version '0.9.1'
        cd ..

        sleep 30
    fi

    if [[ "$deploy_service" == "true" || "$deploy_service" == "delete" || "$deploy_service" == "force" ]]; then
        export COURSE=$course
        export REPO=$repo
        export NAMESPACE=$namespace
        export REGION=$current_region


        export SERVICE_VERSION=$service_version
        export NOTIFIER_ENDPOINT=$notifier_endpoint

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

                        if [ -z "$elasticsearch_kibana_endpoint" ]; then
                            echo "skipping deployment annotation"
                        else
                            echo "adding deployment annotation"
                            ts=$(date -z utc +%FT%TZ)
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
done