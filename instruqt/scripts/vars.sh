source /workspace/workshop/instruqt/scripts/retry.sh

check_host() {
    local host_stripped="${1#*://}"  # Remove protocol (http:// or https://)
    host_stripped="${host_stripped%%/*}"       # Remove trailing paths (everything after /)
    host_stripped="${host_stripped%%:*}"       # Remove port (everything after :)
    echo "$host_stripped"

    if host "$host_stripped" > /dev/null; then
        printf "HOST: $1...reachable\n"
        return 0
    else
        printf "HOST: $1...not yet reachable\n"
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
    export $(curl -s http://es3-api:9000/env | xargs)
elif [[ "$HOSTNAME" == "k3s" ]]; then
    export $(curl -s http://es3-api:9000/env | xargs)
fi

if [ "$wait" = "true" ]; then
    retry_command_lin check_host $FLEET_URL
    retry_command_lin check_host $INGEST_URL
    retry_command_lin check_host $ELASTICSEARCH_URL
    retry_command_lin check_host $KIBANA_URL
fi
