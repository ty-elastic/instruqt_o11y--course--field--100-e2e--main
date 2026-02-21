source assets/scripts/retry.sh

check_assets() {
    kubectl wait --for=condition=complete job/assets-$1 --timeout=120s
}

check_services() {
    kubectl -n $1 rollout status deployment --timeout=5m
}

get_lb_address() {
   printf "$FUNCNAME...\n"
    export SERVICE_IP=$(kubectl -n $1 get service $2 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export SERVICE_PORT=$(kubectl -n $1 get service $2 -o jsonpath='{.spec.ports[0].port}')
    if [ -z "$SERVICE_IP" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi
   printf "$FUNCNAME...SUCCESS\n"
   return 0
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

join_by() {
  local IFS="$1"
  shift
  echo "$*"
}

notifier_endpoint=""

arch=linux/amd64
course=latest
service=all
local=false
namespace_base=trading
region=na,emea
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

proxy_port=8081

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

export MYSQL_HOST=mysql
export MYSQL_USER=root
export MYSQL_PASSWORD=password
export MYSQL_DBNAME=main
export MYSQL_PORT=3306

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

namespaces_array=()
for current_region in "${regions[@]}"; do
    namespace=$namespace_base-$current_region
    echo $namespace
    namespaces_array+=($namespace)
done
namespaces=$(join_by ", " "${namespaces_array[@]}")
echo $namespaces

if [ -f ".env" ]; then
    set -o allexport # Automatically export all variables defined after this point
    source .env
    set +o allexport # Stop automatic exporting
fi

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
    ./build.sh -k $service_version -r $repo -s $service -c $course -a $arch
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

    assets/scripts/otel.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint -o $deploy_otel
fi

if [ "$features" = "true" ]; then
    assets/scripts/features_es.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
fi

printf "deploying services...\n"
for current_region in "${regions[@]}"; do
    namespace=$namespace_base-$current_region
    printf "setup for namespace=$namespace\n"

    export COURSE=$course
    export REPO=$repo
    export NAMESPACE=$namespace
    export REGION=$current_region

    ((proxy_port++))
    export PROXY_PORT=$proxy_port

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
                        #echo $PROXY_PORT
                        #envsubst < k8s/yaml/$current_service.yaml | yq '.spec.ports[].port |= to_number'

                        cat k8s/yaml/$current_service.yaml > tmp.yaml
                        sed "s/{PROXY_PORT}/$PROXY_PORT/g" tmp.yaml > tmp2.yaml
                        envsubst < tmp2.yaml | kubectl apply -f -
                        rm tmp.yaml
                        rm tmp2.yaml

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
        fi
    fi
done
printf "deploying services...SUCCESS\n"

if [ "$profiling" = "true" ]; then
    assets/scripts/profiling.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
fi

if [ "$synthetics" = "true" ]; then
    assets/scripts/synthetics.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
fi

if [ "$remote_endpoint" != "na" ]; then
    cd utils/remote

    if [ "$build_lib" = "true" ]; then
        ./build.sh -r $repo -c $course -a $arch
    fi

    envsubst < remote.yaml | kubectl apply -f -
    cd ../..

    if [ "$remote_endpoint" = "cluster" ]; then
        retry_command_lin get_lb_address utils remote-ext
        remote_endpoint=http://SERVICE_IP:SERVICE_PORT
    fi
fi

if [ "$assets" = "true" ]; then
    cd assets

    if [ "$build_lib" = "true" ]; then
        ./build.sh -r $repo -c $course -a $arch
    fi

    export JOB_ID=$(( $RANDOM ))
    #echo $JOB_ID
    export elasticsearch_kibana_endpoint=$elasticsearch_kibana_endpoint
    export elasticsearch_es_endpoint=$elasticsearch_es_endpoint
    export elasticsearch_api_key=$elasticsearch_api_key  
    export remote_endpoint=$remote_endpoint
    export namespaces=$namespaces

    envsubst < assets.yaml | kubectl apply -f -
    cd ..

    retry_command_lin check_assets $JOB_ID
fi

if [ "$grafana" = "true" ]; then
    cd prometheus-grafana
    envsubst < grafana.yaml | kubectl apply -f -
    cd ..
fi

for current_region in "${regions[@]}"; do
    namespace=$namespace_base-$current_region

    if [[ "$service" == "all" || "$service" == "monkey" ]]; then
        check_services $namespace
        printf "check services for $namespace\n"

        retry_command_lin get_lb_address $namespace proxy-ext
        printf "proxy-ext SERVICE_IP=$SERVICE_IP, SERVICE_PORT=$SERVICE_PORT)\n"
        retry_command_lin start_simulation $SERVICE_IP $SERVICE_PORT
    fi
done

if [ "$assets" = "true" ]; then
    assets/scripts/features_dep.sh -h $elasticsearch_kibana_endpoint -i $elasticsearch_api_key -j $elasticsearch_es_endpoint -k $elasticsearch_otlp_endpoint
fi