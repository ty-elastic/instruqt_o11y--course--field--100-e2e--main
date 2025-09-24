arch=linux/amd64
course=latest
service=all
local=true
variant=none
otel=false
namespace=trading
region=0

elasticsearch_rum_endpoint=""
elasticsearch_kibana_endpoint=""
elasticsearch_api_key=""

postgresql_host=postgresql
postgresql_user=admin
postgresql_password=password
postgresql_sslmode=disable

while getopts "s:a:l:v:o:n:r:c:t:u:v:g:h:i:j:" opt
do
   case "$opt" in
      s ) service="$OPTARG" ;;
      c ) course="$OPTARG" ;;
      o ) otel="$OPTARG" ;;
      a ) arch="$OPTARG" ;;
      l ) local="$OPTARG" ;;
      v ) variant="$OPTARG" ;;
      n ) namespace="$OPTARG" ;;
      r ) region="$OPTARG" ;;
      t ) elasticsearch_rum_endpoint="$OPTARG" ;;
      u ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      v ) elasticsearch_api_key="$OPTARG" ;;
      g ) postgresql_host="$OPTARG" ;;
      h ) postgresql_user="$OPTARG" ;;
      i ) postgresql_password="$OPTARG" ;;
      j ) postgresql_sslmode="$OPTARG" ;;
   esac
done

# echo $local
# if [ "$local" = "true" ]; then
#    docker run -d -p 5093:5000 --restart=always --name registry registry:2
# fi

echo $service

./build.sh -a $arch -c $course -s $service -l $local -v $variant -x true -n $namespace -t $elasticsearch_rum_endpoint -u $elasticsearch_kibana_endpoint -v $elasticsearch_api_key
./deploy.sh -c $course -s $service -l $local -v $variant -o $otel -n $namespace -r $region -e $es_target
