echo "Project type: $PROJECT_TYPE"
echo "Regions: $REGIONS"

export JSON_FILE='/tmp/project_results.json'

case "$PROJECT_TYPE" in
    "observability")
      PRODUCT_TIER="${PRODUCT_TIER:-complete}"
      echo "Project Tier: $PRODUCT_TIER"
      python3 ~/bin/es3-api.py \
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
      echo "Optimized for: $OPTIMIZED_FOR"
      python3 ~/bin/es3-api.py \
        --operation create \
        --project-type $PROJECT_TYPE \
        --optimized-for $OPTIMIZED_FOR \
        --regions $REGIONS \
        --project-name $INSTRUQT_TRACK_SLUG-$INSTRUQT_PARTICIPANT_ID-`date '+%s'` \
        --api-key $ESS_CLOUD_API_KEY \
        --wait-for-ready
        ;;
    "security")
      python3 ~/bin/es3-api.py \
        --operation create \
        --project-type $PROJECT_TYPE \
        --regions $REGIONS \
        --project-name $INSTRUQT_TRACK_SLUG-$INSTRUQT_PARTICIPANT_ID-`date '+%s'` \
        --api-key $ESS_CLOUD_API_KEY \
        --wait-for-ready
        ;;
    *)
        echo "Error: Unknown project type '$PROJECT_TYPE'"
        exit 1
        ;;
esac

timeout=20
counter=0

while [ $counter -lt $timeout ]; do
    if [ -f "$JSON_FILE" ]; then
        echo "File found, continuing..."
        break
    fi

    echo "Waiting for file $JSON_FILE... ($((counter + 1))/$timeout seconds)"
    sleep 1
    counter=$((counter + 1))
done

# Check if we timed out
if [ $counter -eq $timeout ]; then
    echo "Timeout: File $JSON_FILE not found after $timeout seconds"
    exit 1
fi

export KIBANA_URL=`jq -r --arg region "$REGIONS" '.[$region].endpoints.kibana' $JSON_FILE`
export ELASTICSEARCH_PASSWORD=`jq -r --arg region "$REGIONS" '.[$region].credentials.password' $JSON_FILE`
export ES_URL=`jq -r --arg region "$REGIONS" '.[$region].endpoints.elasticsearch' $JSON_FILE`
export ELASTICSEARCH_AUTH_BASE64=$(echo -n "admin:${ELASTICSEARCH_PASSWORD}" | base64)
export KIBANA_URL_WITHOUT_PROTOCOL=$(echo $KIBANA_URL | sed -e 's#http[s]\?://##g')

agent variable set ES_DEPLOYMENT_ID `jq -r --arg region "$REGIONS" '.[$region].id' /tmp/project_results.json`

# ---------------------------------------------------------- APIKEY
echo "Generating API Key"
output=$(curl -X POST -s -u "admin:${ELASTICSEARCH_PASSWORD}" \
  -w "\n%{http_code}" \
  $ES_URL/_security/api_key \
  -H 'Content-Type: application/json' \
  -d '{"name": "collector"}')

# Extract HTTP status code and response body
http_code=$(echo "$output" | tail -n1)
response_body=$(echo "$output" | sed '$d')

# Check if the API call was successful
if [ "$http_code" != "200" ]; then
  echo "Error: Failed to generate API key. HTTP status: $http_code"
  echo "Response: $response_body"
  exit 1
fi

# Extract API key and validate it exists
export ELASTICSEARCH_API_KEY=$(echo "$response_body" | jq -r '.encoded // empty')
if [ -z "$ELASTICSEARCH_API_KEY" ]; then
  echo "Error: Failed to extract API key from response"
  echo "Response: $response_body"
  exit 1
fi

echo "API Key generated successfully"

# Update the JSON file with general api_key (with proper path creation)
if ! jq --arg region "$REGIONS" --arg apikey "$ELASTICSEARCH_API_KEY" \
  '.[$region] = (.[$region] // {}) |
   .[$region].credentials = (.[$region].credentials // {}) |
   .[$region].credentials.api_key = $apikey' \
  $JSON_FILE > $JSON_FILE.tmp; then
  echo "Error: Failed to update JSON with API key"
  exit 1
fi
mv $JSON_FILE.tmp $JSON_FILE

# ---------------------------------------------------------- FLEET

# Fetch the Fleet Server URL(s)
if [ "$PROJECT_TYPE" = 'observability' ]; then
  echo "Fetching Fleet Server URL"

  fleet_output=$(curl -s -u "admin:$ELASTICSEARCH_PASSWORD" \
    -w "\n%{http_code}" \
    -H "kbn-xsrf: true" \
    "$KIBANA_URL/api/fleet/fleet_server_hosts")

  # Extract HTTP status code and response body
  fleet_http_code=$(echo "$fleet_output" | tail -n1)
  fleet_response=$(echo "$fleet_output" | sed '$d')

  # Check if the Fleet API call was successful
  if [ "$fleet_http_code" != "200" ]; then
    echo "Warning: Failed to fetch Fleet Server URL. HTTP status: $fleet_http_code"
    echo "Response: $fleet_response"
    # Continue without fleet URL rather than exiting
  else
    # Extract Fleet URL and validate
    export FLEET_URL=$(echo "$fleet_response" | jq -r '.items[0].host_urls[0] // empty')

    if [ -z "$FLEET_URL" ]; then
      echo "Warning: No Fleet Server URL found in response"
    else
      echo "Fleet URL: $FLEET_URL"

      # Update the JSON file with the Fleet URL
      if ! jq --arg region "$REGIONS" --arg fleet "$FLEET_URL" \
        '.[$region].endpoints = (.[$region].endpoints // {}) |
         .[$region].endpoints.fleet = $fleet' \
        $JSON_FILE > $JSON_FILE.tmp; then
        echo "Error: Failed to update JSON with Fleet URL"
        exit 1
      fi
      mv $JSON_FILE.tmp $JSON_FILE
    fi
  fi
fi

echo "Configuration saved successfully to $JSON_FILE"

# ---------------------------------------------------------- ENV

create_env_file() {
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
}
create_env_file

# ---------------------------------------------------------- NGIX


echo "Configure NGINX proxy"
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
  listen 9100 default_server;
  server_name kibana;

  location / {
    proxy_set_header Host $KIBANA_URL_WITHOUT_PROTOCOL;
    proxy_pass $KIBANA_URL;
    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
    proxy_set_header Connection '';
    proxy_set_header X-Scheme $scheme;
    proxy_set_header Authorization "Basic $ELASTICSEARCH_AUTH_BASE64";
    proxy_set_header Accept-Encoding '';

    proxy_hide_header Content-Security-Policy;
    proxy_set_header Content-Security-Policy "script-src 'self' https://kibana.estccdn.com; worker-src blob: 'self'; style-src 'unsafe-inline' 'self' https://kibana.estccdn.com; style-src-elem 'unsafe-inline' 'self' https://kibana.estccdn.com";
    add_header Content-Security-Policy "script-src 'self' https://kibana.estccdn.com; worker-src blob: 'self'; style-src 'unsafe-inline' 'self' https://kibana.estccdn.com; style-src-elem 'unsafe-inline' 'self' https://kibana.estccdn.com";

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains;";

    proxy_redirect off;
    proxy_http_version 1.1;

    client_max_body_size 20M;

    proxy_read_timeout          600;
    proxy_send_timeout          300;
    send_timeout                300;
    proxy_connect_timeout       300;
 }
}

server {
  listen 9200;
  server_name elasticsearch;

  location / {
    proxy_pass $ES_URL;
    proxy_connect_timeout       300;
    proxy_send_timeout          300;
    proxy_read_timeout          300;
    send_timeout                300;
  }
}
EOF

echo "Restart NGINX"
systemctl restart nginx

