arch=linux/amd64
repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
course=o11y--course--field--demo-oneworkflow--main
current_service=remote

while getopts "a:c:r:" opt
do
   case "$opt" in
      a ) arch="$OPTARG" ;;
      c ) course="$OPTARG" ;;
      r ) repo="$OPTARG" ;;
   esac
done

export IMAGE_NAME_PREFIX="autoinstrumentation-apache-httpd"
export IMAGE_VERSION=`cat version.txt`
export IMAGE_NAME=${repo}/${IMAGE_NAME_PREFIX}:${IMAGE_VERSION}

echo $repo

docker buildx build --platform $arch \
    --progress plain -t $IMAGE_NAME --output "type=registry,name=${IMAGE_NAME}" .

