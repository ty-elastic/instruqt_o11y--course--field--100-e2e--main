export INSTRUQT_TRACK_SLUG=o11y--course--field--100-e2e--serverless
export REPO=us-central1-docker.pkg.dev/elastic-sa/tbekiares
export COURSE=$INSTRUQT_TRACK_SLUG

export NAMESPACE=utils
envsubst < cpuhog.yaml | kubectl apply -f -
