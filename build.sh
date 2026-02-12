source assets/scripts/retry.sh

check_assets() {
    kubectl wait --for=condition=complete job/assets-$1 --timeout=120s
}

check_services() {
    kubectl -n $1 rollout status deployment --timeout=5m
}

start_simulation() {
   printf "$FUNCNAME...\n"
    output=$(curl -s -X POST "http://$1:$2/monkey/simulation/start" \
        -w "\n%{http_code}")
   # Extract HTTP status code
   http_code=$(echo "$output" | tail -n1)
   http_response=$(echo "$output" | sed '$d')
   if [ "$http_code" != "200" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi
   printf "$FUNCNAME...SUCCESS\n"
   return 0
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
grafana=false
features=false
deploy_ebpf_services=false

build_service=false
build_lib=false
deploy_otel=false
deploy_service=false
annotations=false
synthetics=false

elasticsearch_es_endpoint="na"
elasticsearch_kibana_endpoint="na"
elasticsearch_api_key="na"
elasticsearch_otlp_endpoint="na"
remote_endpoint="na"

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux;;
    Darwin*)    machine=Mac;;
    *)          machine="UNKNOWN:${unameOut}"
esac

while getopts "a:c:s:l:b:x:o:d:r:v:g:h:i:j:k:w:y:p:e:m:f:n:" opt
do
   case "$opt" in
      a ) arch="$OPTARG" ;;
      c ) course="$OPTARG" ;;
      s ) service="$OPTARG" ;;
      l ) local="$OPTARG" ;;

      f ) features="$OPTARG" ;;
      g ) grafana="$OPTARG" ;;

      b ) build_service="$OPTARG" ;;
      x ) build_lib="$OPTARG" ;;
      o ) deploy_otel="$OPTARG" ;;
      d ) deploy_service="$OPTARG" ;;
      n ) deploy_ebpf_services="$OPTARG" ;;

      r ) region="$OPTARG" ;;
      v ) service_version="$OPTARG" ;;

      p ) profiling="$OPTARG" ;;
      e ) remote_endpoint="$OPTARG" ;;

      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      k ) elasticsearch_otlp_endpoint="$OPTARG" ;;

      m ) synthetics="$OPTARG" ;;

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

printf "deploying services...\n"

for current_region in "${regions[@]}"; do

    namespace=$namespace_base-$current_region
    printf "setup for namespace=$namespace\n"

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

        cd ./assets
        ./build.sh -r $repo -c $course -a $arch
        cd .. 
    fi

    if [ "$deploy_otel" != "false" ]; then
        # ---------- COLLECTOR
        if [ "$deploy_otel" = "true" ]; then
            deploy_otel="stack"
        fi

        assets/scripts/otel.sh  -n $namespace -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint -o $deploy_otel
    fi

    if [ "$features" = "true" ]; then
        assets/scripts/features_es.sh  -n $namespace -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
    fi

    export COURSE=$course
    export REPO=$repo
    export NAMESPACE=$namespace
    export REGION=$current_region

    if [[ "$deploy_service" == "true" || "$deploy_service" == "delete" || "$deploy_service" == "force" ]]; then
        export SERVICE_VERSION=$service_version
        export NOTIFIER_ENDPOINT=$notifier_endpoint

        export JOB_ID=$(( $RANDOM ))
        #echo $JOB_ID

        envsubst < k8s/yaml/_namespace.yaml | kubectl apply -f -

        if [ "$service" != "none" ]; then
            for file in k8s/yaml/*.yaml; do
                current_service=$(basename "$file")
                current_service="${current_service%.*}"

                if [[ "$service" == "all" || "$service" == "$current_service" ]]; then

                    if [[ "$current_service" == "recorder-go-zero" && $deploy_ebpf_services == "false" ]]; then
                        printf "deleting $current_service from region $REGION\n"
                        envsubst < k8s/yaml/$current_service.yaml | kubectl delete -f -
                        printf "skipping recorder-go-zero deployment...\n"
                        continue
                    fi


                    if [ "$deploy_service" = "delete" ]; then
                        printf "deleting $current_service from region $REGION\n"
                        envsubst < k8s/yaml/$current_service.yaml | kubectl delete -f -
                    else


                        printf "deploying $current_service to region $REGION\n"
                        envsubst < k8s/yaml/$current_service.yaml | kubectl apply -f -
                        if [ "$deploy_service" = "force" ]; then
                            kubectl -n $namespace rollout restart deployment/$current_service
                        fi

                        if [ "$annotations" = "true" ]; then
                            printf "adding deployment annotation for $current_service\n"
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

            if [[ "$service" == "all" || "$service" == "monkey" ]]; then
                check_services $namespace

                SERVICE_IP=$(kubectl -n trading-1 get service proxy-ext -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                SERVICE_PORT=$(kubectl -n trading-1 get service proxy-ext -o jsonpath='{.spec.ports[0].port}')
                printf "proxy-ext SERVICE_IP=$SERVICE_IP, SERVICE_PORT=$SERVICE_PORT)\n"

                retry_command_lin start_simulation $SERVICE_IP $SERVICE_PORT
            fi
        fi
    fi

    if [ "$profiling" = "true" ]; then
        assets/scripts/features_dep.sh  -n $namespace -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
        assets/scripts/profiling.sh -n $namespace -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
    fi

    if [ "$synthetics" = "true" ]; then
        assets/scripts/synthetics.sh -n $namespace -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
    fi

    if [ "$remote_endpoint" != "na" ]; then
        cd utils/remote
        envsubst < remote.yaml | kubectl apply -f -
        cd ../..

        if [ "$remote_endpoint" = "cluster" ]; then
            check_services $namespace
            SERVICE_IP=$(kubectl -n trading-1 get service remote-ext -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
            SERVICE_PORT=$(kubectl -n trading-1 get service remote-ext -o jsonpath='{.spec.ports[0].port}')
            remote_endpoint=http://SERVICE_IP:SERVICE_PORT
        fi
    fi

    if [ "$assets" = "true" ]; then
        cd assets
        export JOB_ID=$(( $RANDOM ))
        #echo $JOB_ID
        export elasticsearch_kibana_endpoint=$elasticsearch_kibana_endpoint
        export elasticsearch_es_endpoint=$elasticsearch_es_endpoint
        export elasticsearch_api_key=$elasticsearch_api_key  
        export remote_endpoint=$remote_endpoint  
        envsubst < assets.yaml | kubectl apply -f -
        cd ..

        retry_command_lin check_assets $JOB_ID
    fi

    if [ "$grafana" = "true" ]; then
        cd prometheus-grafana
        envsubst < grafana.yaml | kubectl apply -f -
        cd ..
    fi
    
done

printf "deploying services...SUCCESS\n"
