arch=linux/amd64
repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
course=latest
current_service=snowem

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
