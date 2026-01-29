source /opt/workshops/elastic-retry.sh
export $(curl http://kubernetes-vm:9000/env | xargs)

export INSTRUQT_TRACK_SLUG=o11y--course--field--100-e2e--main
export REPO=us-central1-docker.pkg.dev/elastic-sa/tbekiares
export COURSE=$INSTRUQT_TRACK_SLUG

kubectl delete deployment/cpuhog
