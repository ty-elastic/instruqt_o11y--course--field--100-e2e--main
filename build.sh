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

database=postgresql

while getopts "a:c:s:l:b:x:o:d:r:v:p:" opt
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
      p ) database="$OPTARG" ;;
   esac
done

if [ "$database" = "mssql" ]; then
    echo "using mssql"
    postgresql_host=mssql
    postgresql_user=sa
    postgresql_password=Pa55w0rd2019
    postgresql_dbname=trades
    db_port=1433
    db_protocol=sqlserver
    db_setup=none
    db_options=";databaseName=trades;integratedSecurity=false;encrypt=false;trustServerCertificate=true"
    db_dialect="SQLServerDialect"
else
    echo "using postgresql"
    postgresql_host=postgresql
    postgresql_user=postgres
    postgresql_password=postgres
    postgresql_dbname=trades
    db_protocol=postgresql
    db_setup=none
    db_options="/trades?sslmode=disable"
    db_port=5432
    db_dialect=PostgreSQLDialect
fi

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
    
    export $(cat ./.env-$current_region | xargs)

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
        export POSTGRESQL_HOST=$postgresql_host
        export POSTGRESQL_USER=$postgresql_user
        export POSTGRESQL_PASSWORD=$postgresql_password
        export POSTGRESQL_DBNAME=$postgresql_dbname
        export DB_PROTOCOL=$db_protocol
        export DB_SETUP=$db_setup
        export DB_OPTIONS=$db_options
        export DB_PORT=$db_port
        export DB_DIALECT=$db_dialect

        export SERVICE_VERSION=$service_version
        export NOTIFIER_ENDPOINT=$notifier_endpoint

        envsubst < k8s/yaml/_namespace.yaml | kubectl apply -f -

        if [ "$service" != "none" ]; then
            for file in k8s/yaml/*.yaml; do
                current_service=$(basename "$file")
                current_service="${current_service%.*}"

                if [[ "$current_service" == "mssql" && "$db_protocol" == "postgresql" ]]; then
                    continue
                elif [[ "$current_service" == "postgresql" && "$db_protocol" == "sqlserver" ]]; then
                    continue
                fi

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
            done
        fi
    fi
done