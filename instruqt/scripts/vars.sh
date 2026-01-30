source /workspace/workshop/instruqt/scripts/retry.sh

if [[ "$HOSTNAME" == "es3-api" ]]; then
    retry_command_lin curl http://es3-api:9000/env
    export $(curl http://es3-api:9000/env | xargs)
elif [[ "$HOSTNAME" == "k3s" ]]; then
    retry_command_lin curl http://es3-api:9000/env
    export $(curl http://es3-api:9000/env | xargs)
fi
