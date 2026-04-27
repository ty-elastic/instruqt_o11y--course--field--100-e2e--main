export REPO=us-central1-docker.pkg.dev/elastic-sa/tbekiares
export COURSE=o11y--course--field--100-e2e--serverless

envsubst < pos.yaml | kubectl delete -f -
envsubst < pos.yaml | kubectl apply -f -
