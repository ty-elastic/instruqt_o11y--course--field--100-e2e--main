## DEPLOY
GCP_PROJECT_ID=elastic-sa
GCP_REGION=us-central1
GCP_LABELS="division=field,org=sa,team=pura,project=tyronebekiares"

TOOL_NAME=tbekiares-demo

gcloud auth configure-docker $GCP_REGION-docker.pkg.dev

deploy_app() {
    docker build --platform linux/amd64 -t $GCP_REGION-docker.pkg.dev/$GCP_PROJECT_ID/$TOOL_NAME/$TOOL_NAME-$1 .
    docker push $GCP_REGION-docker.pkg.dev/$GCP_PROJECT_ID/$TOOL_NAME/$TOOL_NAME-$1

    gcloud run deploy $TOOL_NAME-$1 --no-cpu-throttling --cpu 2 --memory 2G --labels $GCP_LABELS --region $GCP_REGION --allow-unauthenticated --cpu-boost --min-instances $2 --max-instances $3 --image $GCP_REGION-docker.pkg.dev/$GCP_PROJECT_ID/$TOOL_NAME/$TOOL_NAME-$1
    gcloud run services describe $TOOL_NAME-$1 --region $GCP_REGION --format export > $TOOL_NAME-$1.yaml
    HC_HTTP_PATH=$4 yq -i "
    .spec.template.spec.containers[0].startupProbe = {} |
    .spec.template.spec.containers[0].startupProbe.httpGet.path = env(HC_HTTP_PATH) |
    .spec.template.spec.containers[0].startupProbe.httpGet.port = 8080 |
    .spec.template.spec.containers[0].livenessProbe = {} |
    .spec.template.spec.containers[0].livenessProbe.httpGet.path = env(HC_HTTP_PATH) |
    .spec.template.spec.containers[0].livenessProbe.httpGet.port = 8080
    " $TOOL_NAME-$1.yaml
    gcloud run services replace $TOOL_NAME-$1.yaml
    rm $TOOL_NAME-$1.yaml
}
deploy_app aiassistant 2 100 "/health"