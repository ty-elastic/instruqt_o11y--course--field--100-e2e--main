source /workspace/workshop/instruqt/scripts/retry.sh

export $(curl http://kubernetes-vm:9000/env | xargs)

if ! host es3-api > /dev/null; then
    export $(curl http://kubernetes-vm:9000/env | xargs)
else
    export $(curl http://es3-api:9000/env | xargs)
fi
