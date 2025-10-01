for i in static/js/*.js; do
  echo "UPLOADING sourcemap for ${i}"
  curl -iv --limit-rate 400K -X POST "$ELASTICSEARCH_KIBANA_ENDPOINT/api/apm/sourcemaps" \
  -H 'Content-Type: multipart/form-data' \
  -H 'kbn-xsrf: true' \
  -H "Authorization: ApiKey ${ELASTICSEARCH_APIKEY}" \
  -F "service_name=${SERVICE_NAME}" \
  -F "service_version=${SERVICE_VERSION}" \
  -F "bundle_filepath=/${i}" \
  -F "sourcemap=@${i}.map"
  sleep 5
done
