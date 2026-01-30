source /workspace/workshop/instruqt/scripts/retry.sh

if [ -n "$(dig +short es3-api)" ]; then
    retry_command_lin curl http://es3-api:9000/env
    export $(curl http://es3-api:9000/env | xargs)
else
    retry_command_lin curl http://kubernetes-vm:9000/env
    export $(curl http://kubernetes-vm:9000/env | xargs)
fi
