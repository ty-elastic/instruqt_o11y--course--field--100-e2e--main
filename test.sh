export COURSE=demo

./build.sh -c $COURSE -d false -b true -x true -s all -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL

# platform
./build.sh -o false -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL -f true

# services
./build.sh -o serverless -c $COURSE -d true -n true -b false -s all -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL

# synthetics, profiling
./build.sh -o false -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL -p true -m true

export REMOTE_HOSTNAME=$(kubectl -n trading-na get svc proxy-ext -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export REMOTE_PORT=$(kubectl -n trading-na get svc proxy-ext -o jsonpath='{.spec.ports[0].port}')

# assets
./build.sh -o false -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL -w true -e http://$HREMOTE_HOSTNAME:$REMOTE_PORT

# grafana
#./build.sh -o false -c $COURSE -d false -b false -s none -j $ELASTICSEARCH_URL -h $KIBANA_URL -i $ELASTICSEARCH_APIKEY -k $MOTEL_INGEST_URL -g true

# logs
./build.sh -o false -c $COURSE -d false -b true -u true
