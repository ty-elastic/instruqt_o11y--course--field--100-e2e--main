course=o11y--course--field--100-e2e--main
repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares

export COURSE=$course
export REPO=$repo

envsubst < cpuhog.yaml | kubectl apply -f -
