arch=linux/amd64
course=latest
service=all
local=false
namespace=trading

elasticsearch_rum_endpoint=""
elasticsearch_kibana_endpoint=""
elasticsearch_api_key=""

build_service=true
build_lib=true

while getopts "a:l:c:s:x:z:n:t:u:v:" opt
do
   case "$opt" in
      a ) arch="$OPTARG" ;;
      c ) course="$OPTARG" ;;
      s ) service="$OPTARG" ;;
      l ) local="$OPTARG" ;;
      x ) build_service="$OPTARG" ;;
      z ) build_lib="$OPTARG" ;;
      n ) namespace="$OPTARG" ;;
      t ) elasticsearch_rum_endpoint="$OPTARG" ;;
      u ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      v ) elasticsearch_api_key="$OPTARG" ;;
   esac
done

repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
if [ "$local" = "true" ]; then
    docker run -d -p 5093:5000 --restart=always --name registry registry:2
    repo=localhost:5093
fi

if [ "$build_service" = "true" ]; then
    cd ./src
    ./build.sh -r $repo -s $service -c $course -a $arch -n $namespace -t $elasticsearch_rum_endpoint -u $elasticsearch_kibana_endpoint -v $elasticsearch_api_key
    cd ..
fi

if [ "$build_lib" = "true" ]; then
    cd ./lib
    ./build.sh -r $repo -c $course -a $arch
    cd ..
fi
