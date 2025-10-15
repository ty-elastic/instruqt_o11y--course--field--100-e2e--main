arch=linux/amd64
course=latest
repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
service=all
namespace=trading
service_version="1.0"

elasticsearch_rum_endpoint=""
elasticsearch_kibana_endpoint=""
elasticsearch_api_key=""

while getopts "r:a:c:s:n:t:u:v:k:" opt
do
   case "$opt" in
      a ) arch="$OPTARG" ;;
      c ) course="$OPTARG" ;;
      r ) repo="$OPTARG" ;;
      s ) service="$OPTARG" ;;
      n ) namespace="$OPTARG" ;;
      t ) elasticsearch_rum_endpoint="$OPTARG" ;;
      u ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      v ) elasticsearch_api_key="$OPTARG" ;;
      k ) service_version="$OPTARG" ;;
   esac
done

echo $elasticsearch_rum_endpoint
echo $elasticsearch_kibana_endpoint
echo $elasticsearch_api_key

for service_dir in ./*/; do
    echo $service_dir
    if [[ -d "$service_dir" ]]; then
        current_service=$(basename "$service_dir")
        if [[ "$service" == "all" || "$current_service" == "$service" ]]; then
            echo $service
            echo $course

            if [[ "$service" == "chaos" ]]; then
                cp ../k8s/yaml/*.yaml $service/yaml/
            fi

            docker buildx build --platform $arch \
                --build-arg NAMESPACE=$namespace \
                --build-arg SERVICE_VERSION=$service_version \
                --build-arg ELASTICSEARCH_RUM_ENDPOINT=$elasticsearch_rum_endpoint \
                --build-arg ELASTICSEARCH_KIBANA_ENDPOINT=$elasticsearch_kibana_endpoint \
                --build-arg ELASTICSEARCH_APIKEY=$elasticsearch_api_key \
                --progress plain -t $repo/$current_service:$course --output "type=registry,name=$repo/$current_service:$course" $service_dir
        fi
    fi
done
