if [ -f ".env" ]; then
    set -o allexport # Automatically export all variables defined after this point
    source .env
    set +o allexport # Stop automatic exporting
fi

envsubst '$COURSE,$ELASTICSEARCH_URL,$KIBANA_URL,$ELASTICSEARCH_APIKEY,$INGEST_URL,$FLEET_URL' < install/install.yaml | kubectl apply -f -
kubectl logs -f job/superdemo-install
