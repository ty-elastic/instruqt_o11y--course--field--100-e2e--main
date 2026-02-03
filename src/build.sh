arch=linux/amd64
course=latest
repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
service=all
namespace=trading
service_version="1.0"

while getopts "r:a:c:s:n:k:e:f:g:h:i:" opt
do
   case "$opt" in
      a ) arch="$OPTARG" ;;
      c ) course="$OPTARG" ;;
      r ) repo="$OPTARG" ;;
      s ) service="$OPTARG" ;;
      n ) namespace="$OPTARG" ;;
      k ) service_version="$OPTARG" ;;
   esac
done

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
                --progress plain -t $repo/$current_service:$course --output "type=registry,name=$repo/$current_service:$course" $service_dir
        fi
    fi
done
