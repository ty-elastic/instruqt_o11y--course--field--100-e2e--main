source /workspace/workshop/instruqt/scripts/retry.sh

strip_hostname() {
    local url="${1#*://}"  # Remove protocol (http:// or https://)
    url="${url%%/*}"       # Remove trailing paths (everything after /)
    url="${url%%:*}"       # Remove port (everything after :)
    echo "$url"
}

check_host() {
    host_stripped=$(strip_hostname $1)
    if host "$host_stripped" > /dev/null; then
        echo "host reachable"
        return 0
    else
        echo "host not yet reachable"
        return 1
    fi
}

wait=false
while getopts "w:" opt
do
   case "$opt" in
      w ) wait="$OPTARG" ;;
   esac
done

if [ "$wait" = "true" ]; then
    if [[ "$HOSTNAME" == "es3-api" ]]; then
        retry_command_lin curl http://es3-api:9000/env
    elif [[ "$HOSTNAME" == "k3s" ]]; then
        retry_command_lin curl http://es3-api:9000/env
    fi
fi

if [[ "$HOSTNAME" == "es3-api" ]]; then
    export $(curl http://es3-api:9000/env | xargs)
elif [[ "$HOSTNAME" == "k3s" ]]; then
    export $(curl http://es3-api:9000/env | xargs)
fi

if [ "$wait" = "true" ]; then
    retry_command_lin check_host $FLEET_URL
    retry_command_lin check_host $INGEST_URL
    retry_command_lin check_host $ELASTICSEARCH_URL
    retry_command_lin check_host $KIBANA_URL
fi
