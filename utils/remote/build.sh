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

echo $repo

docker buildx build --platform $arch \
    --progress plain -t $repo/$current_service:$course --output "type=registry,name=$repo/$current_service:$course" .
