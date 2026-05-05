#!/bin/bash
WORKING_DIR=/workspace/workshop

source $WORKING_DIR/instruqt/scripts/retry.sh

create_serverless_prj() {
  printf "$FUNCNAME...\n"
  printf "$PROJECT_TYPE in $REGIONS\n"

  export ES3_API_PY=$WORKING_DIR/instruqt/scripts/serverless/es3-api.py
  export JSON_FILE='/tmp/project_results.json'

  case "$PROJECT_TYPE" in
      "observability")
        PRODUCT_TIER="${PRODUCT_TIER:-complete}"
        printf "Project Tier: $PRODUCT_TIER\n"
        python3 $ES3_API_PY \
          --operation create \
          --project-type $PROJECT_TYPE \
          --product-tier $PRODUCT_TIER \
          --regions $REGIONS \
          --project-name $INSTRUQT_TRACK_SLUG-$INSTRUQT_PARTICIPANT_ID-`date '+%s'` \
          --api-key $ESS_CLOUD_API_KEY \
          --wait-for-ready
          ;;
      "elasticsearch")
        OPTIMIZED_FOR="${OPTIMIZED_FOR:-general_purpose}"
        printf "Optimized for: $OPTIMIZED_FOR\n"
        python3 $ES3_API_PY \
          --operation create \
          --project-type $PROJECT_TYPE \
          --optimized-for $OPTIMIZED_FOR \
          --regions $REGIONS \
          --project-name $INSTRUQT_TRACK_SLUG-$INSTRUQT_PARTICIPANT_ID-`date '+%s'` \
          --api-key $ESS_CLOUD_API_KEY \
          --wait-for-ready
          ;;
      "security")
        python3 $ES3_API_PY \
          --operation create \
          --project-type $PROJECT_TYPE \
          --regions $REGIONS \
          --project-name $INSTRUQT_TRACK_SLUG-$INSTRUQT_PARTICIPANT_ID-`date '+%s'` \
          --api-key $ESS_CLOUD_API_KEY \
          --wait-for-ready
          ;;
      *)
          printf "Error: Unknown project type '$PROJECT_TYPE'\n"
          exit 1
          ;;
  esac

  timeout=20
  counter=0

  while [ $counter -lt $timeout ]; do
      if [ -f "$JSON_FILE" ]; then
          printf "$JSON_FILE File found, continuing...\n"
          break
      fi

      printf "Waiting for file $JSON_FILE... ($((counter + 1))/$timeout seconds)\n"
      sleep 1
      counter=$((counter + 1))
  done

  # Check if we timed out
  if [ $counter -eq $timeout ]; then
      printf "Timeout: File $JSON_FILE not found after $timeout seconds\n"
      exit 1
  fi

  export KIBANA_URL=`jq -r --arg region "$REGIONS" '.[$region].endpoints.kibana' $JSON_FILE`
  export ELASTICSEARCH_PASSWORD=`jq -r --arg region "$REGIONS" '.[$region].credentials.password' $JSON_FILE`
  export ES_URL=`jq -r --arg region "$REGIONS" '.[$region].endpoints.elasticsearch' $JSON_FILE`
  export ELASTICSEARCH_AUTH_BASE64=$(echo -n "admin:${ELASTICSEARCH_PASSWORD}" | base64)
  export KIBANA_URL_WITHOUT_PROTOCOL=$(echo $KIBANA_URL | sed -e 's#http[s]\?://##g')

  agent variable set ES_DEPLOYMENT_ID `jq -r --arg region "$REGIONS" '.[$region].id' /tmp/project_results.json`

  printf "$FUNCNAME...SUCCESS\n"
}
create_serverless_prj

# ---------------------------------------------------------- APIKEY

generate_es_apikey() {
  printf "$FUNCNAME...\n"

  output=$(curl -s -X POST "$ES_URL/_security/api_key" \
      -w "\n%{http_code}" \
      -H 'Content-Type: application/json' \
      -u "admin:$ELASTICSEARCH_PASSWORD" \
      -d '{"name": "demo"}')

  # Extract HTTP status code
  http_code=$(echo "$output" | tail -n1)
  http_response=$(echo "$output" | sed '$d')
  if [ "$http_code" != "200" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      exit 1
  fi

  # Extract API key and validate it exists
  export ELASTICSEARCH_API_KEY=$(echo "$http_response" | jq -r '.encoded // empty')
  if [ -z "$ELASTICSEARCH_API_KEY" ]; then
    printf "$FUNCNAME...ERROR: Failed to extract API key from response\n"
    exit 1
  fi

  printf "$FUNCNAME...ELASTICSEARCH_API_KEY=$ELASTICSEARCH_API_KEY\n"

  # Update the JSON file with general api_key (with proper path creation)
  if ! jq --arg region "$REGIONS" --arg apikey "$ELASTICSEARCH_API_KEY" \
    '.[$region] = (.[$region] // {}) |
    .[$region].credentials = (.[$region].credentials // {}) |
    .[$region].credentials.api_key = $apikey' \
    $JSON_FILE > $JSON_FILE.tmp; then
    printf "$FUNCNAME...ERROR: Failed to update JSON with API key\n"
    exit 1
  fi
  mv $JSON_FILE.tmp $JSON_FILE

  printf "$FUNCNAME...SUCCESS\n"
}
generate_es_apikey

# ---------------------------------------------------------- FLEET

get_fleet_url() {
  printf "$FUNCNAME...\n"

  output=$(curl -s -X GET "$KIBANA_URL/api/fleet/fleet_server_hosts" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -u "admin:$ELASTICSEARCH_PASSWORD")

  # Extract HTTP status code
  http_code=$(echo "$output" | tail -n1)
  http_response=$(echo "$output" | sed '$d')
  if [ "$http_code" != "200" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
  fi

  # Extract Fleet URL and validate
  export FLEET_URL=$(echo "$http_response" | jq -r '.items[0].host_urls[0] // empty')

  if [ -z "$FLEET_URL" ]; then
    printf "$FUNCNAME...ERROR: FLEET_URL is unset\n"
    return 1
  fi

  printf "$FUNCNAME...FLEET_URL=$FLEET_URL\n"

  # Update the JSON file with the Fleet URL
  if ! jq --arg region "$REGIONS" --arg fleet "$FLEET_URL" \
    '.[$region].endpoints = (.[$region].endpoints // {}) |
    .[$region].endpoints.fleet = $fleet' \
    $JSON_FILE > $JSON_FILE.tmp; then
    printf "$FUNCNAME...ERROR: Failed to update JSON with Fleet URL\n"
    return 1
  fi

  mv $JSON_FILE.tmp $JSON_FILE
  
  printf "$FUNCNAME...SUCCESS\n"
  return 0
}
# Fetch the Fleet Server URL(s)
if [ "$PROJECT_TYPE" = 'observability' ]; then
  retry_command_lin get_fleet_url
fi

printf "Configuration saved successfully to $JSON_FILE\n"

# ---------------------------------------------------------- ENV

create_env_file() {
  printf "$FUNCNAME...\n"

  mkdir -p "/usr/share/nginx/html"
  # Write environment variables to $HOME/.env with export, extracting values directly with jq
  cat > "/usr/share/nginx/html/env" <<EOF
APM_URL=$(jq -r '.[].endpoints.apm' "$JSON_FILE")
ELASTICSEARCH_URL=$(jq -r '.[].endpoints.elasticsearch' "$JSON_FILE")
INGEST_URL=$(jq -r '.[].endpoints.ingest' "$JSON_FILE")
KIBANA_URL=$(jq -r '.[].endpoints.kibana' "$JSON_FILE")
FLEET_URL=$(jq -r '.[].endpoints.fleet' "$JSON_FILE")
ELASTICSEARCH_APIKEY=$(jq -r '.[].credentials.api_key' "$JSON_FILE")
ELASTICSEARCH_USER=$(jq -r '.[].credentials.username' "$JSON_FILE")
ELASTICSEARCH_PASSWORD=$(jq -r '.[].credentials.password' "$JSON_FILE")
ELASTICSEARCH_AUTH_BASE64=$ELASTICSEARCH_AUTH_BASE64
EOF

  printf "$FUNCNAME...SUCCESS\n"
}
create_env_file

# ---------------------------------------------------------- NGINX

curl -s -o /etc/ssl/certs/sandbox.crt -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssl-certificate"

curl -s -o /etc/ssl/private/sandbox.key -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssl-certificate-key"

configure_nginx_proxy() {
  printf "$FUNCNAME...\n"

  # Configure nginx
  cat > "/etc/nginx/conf.d/default.conf" <<EOF
server {
  listen 9000 default_server;
  server_name env;

  location /nginx_status {
    stub_status on;
    allow 127.0.0.1;
    deny all;
  }
  
  location /env {
    alias /usr/share/nginx/html/env;
  }
}

server {
  listen 60088 ssl;
  server_name kibana.$HOSTNAME.$_SANDBOX_ID.instruqt.io;
  ssl_certificate     /etc/ssl/certs/sandbox.crt;
  ssl_certificate_key /etc/ssl/private/sandbox.key;

  location / {
    proxy_pass $KIBANA_URL;
    proxy_cache off;

    proxy_set_header Host $KIBANA_URL_WITHOUT_PROTOCOL;
    proxy_set_header Authorization "Basic $ELASTICSEARCH_AUTH_BASE64";

    proxy_set_header Connection "";
    proxy_http_version 1.1;

    proxy_read_timeout 300s;
    proxy_send_timeout 300s;

    proxy_hide_header Content-Security-Policy;
    proxy_hide_header X-Frame-Options;
    add_header Content-Security-Policy "script-src 'report-sample' 'self' kibana.estccdn.com; worker-src 'report-sample' 'self' blob: kibana.estccdn.com; style-src 'report-sample' 'self' 'unsafe-inline' *.elastic.co:* *.elstc.co:* kibana.estccdn.com; object-src 'report-sample' 'none'; connect-src 'self' https:; font-src 'self' *.elastic.co:* *.elstc.co:* kibana.estccdn.com; img-src 'self' *.elastic.co:* *.elstc.co:* data: blob: kibana.estccdn.com; report-to violations-endpoint";
  }
}

server {
  listen 60089 ssl;
  server_name remote.$HOSTNAME.$_SANDBOX_ID.instruqt.io;
  ssl_certificate     /etc/ssl/certs/sandbox.crt;
  ssl_certificate_key /etc/ssl/private/sandbox.key;

  location / {
    proxy_pass http://k3s:43210;
    proxy_cache off;

    proxy_http_version 1.1;
  }
}

server {
  listen 60090 ssl;
  server_name snowem.$HOSTNAME.$_SANDBOX_ID.instruqt.io;
  ssl_certificate     /etc/ssl/certs/sandbox.crt;
  ssl_certificate_key /etc/ssl/private/sandbox.key;

  location / {
    proxy_pass http://k3s:43211;
    proxy_cache off;

    proxy_http_version 1.1;
  }
}
EOF

  systemctl restart nginx
  printf "$FUNCNAME...SUCCESS\n"
}
configure_nginx_proxy