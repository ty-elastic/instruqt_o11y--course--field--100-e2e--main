arch=linux/amd64
course=latest
repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
service=all
service_version="1.0"

OPTIND=1
while getopts "r:a:c:s:n:k:e:f:g:h:i:" opt
do
   case "$opt" in
      a ) arch="$OPTARG" ;;
      c ) course="$OPTARG" ;;
      r ) repo="$OPTARG" ;;
      s ) service="$OPTARG" ;;
      k ) service_version="$OPTARG" ;;
   esac
done

if [[ "$service" == processor-* ]]; then
    service="processor"
fi

for service_dir in ./*/; do
    echo $service_dir
    if [[ -d "$service_dir" ]]; then
        current_service=$(basename "$service_dir")
        if [[ "$service" == "all" || "$current_service" == "$service" ]]; then
            echo $service
            echo $course

            docker buildx build --platform $arch \
                --build-arg SERVICE_VERSION=$service_version \
                --progress plain -t $repo/$current_service:$course --output "type=registry,name=$repo/$current_service:$course" $service_dir
        fi
    fi
done
