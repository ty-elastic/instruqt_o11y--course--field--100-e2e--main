export COURSE=latest
WORKING_DIR=$PWD

if [ -f ".env" ]; then
    set -o allexport # Automatically export all variables defined after this point
    source .env
    set +o allexport # Stop automatic exporting
fi

./build.sh -c $COURSE -1 true

./build.sh -c $COURSE -d false -b true -x true -s all -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL


# platform
./build.sh -o false -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL -f true

# services
./build.sh -o serverless -c $COURSE -d force -n true -b false -s all -t $FLEET_URL -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL

# synthetics, profiling
./build.sh -o false -c $COURSE -d false -b false -s none -t $FLEET_URL -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL -p true -m true

export REMOTE_HOSTNAME=$(kubectl -n trading-na get svc proxy-ext -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export REMOTE_PORT=$(kubectl -n trading-na get svc proxy-ext -o jsonpath='{.spec.ports[0].port}')

# assets
./build.sh -o false -c $COURSE -x true -d false -b true -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL -w true -e http://$REMOTE_HOSTNAME:$REMOTE_PORT

# grafana
./build.sh -o false -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL -g true

# logs
./build.sh -o false -c $COURSE -d false -b true -u true

export REMOTE_HOSTNAME=$(kubectl -n utils get svc snowem-ext -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export REMOTE_PORT=$(kubectl -n utils get svc snowem-ext -o jsonpath='{.spec.ports[0].port}')

# snowem
./build.sh -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -j $ELASTICSEARCH_URL -q true -e https://$REMOTE_HOSTNAME:$REMOTE_PORT

# ramen
assets/scripts/ramen.sh -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -j $ELASTICSEARCH_URL
