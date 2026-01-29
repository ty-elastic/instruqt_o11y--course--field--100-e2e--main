echo "Project type: $PROJECT_TYPE"
echo "Regions: $REGIONS"

case "$PROJECT_TYPE" in
    "observability")
      PRODUCT_TIER="${PRODUCT_TIER:-complete}"
      echo "Project Tier: $PRODUCT_TIER"
      python3 bin/es3-api.py \
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
      python3 bin/es3-api.py \
        --operation create \
        --project-type $PROJECT_TYPE \
        --optimized-for $OPTIMIZED_FOR \
        --regions $REGIONS \
        --project-name $INSTRUQT_TRACK_SLUG-$INSTRUQT_PARTICIPANT_ID-`date '+%s'` \
        --api-key $ESS_CLOUD_API_KEY \
        --wait-for-ready
        ;;
    "security")
      python3 bin/es3-api.py \
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
    if [ -f "/tmp/project_results.json" ]; then
        echo "File found, continuing..."
        break
    fi

    echo "Waiting for file /tmp/project_results.json... ($((counter + 1))/$timeout seconds)"
    sleep 1
    counter=$((counter + 1))
done

# Check if we timed out
if [ $counter -eq $timeout ]; then
    echo "Timeout: File /tmp/project_results.json not found after $timeout seconds"
    exit 1
fi

export KIBANA_URL=`jq -r --arg region "$REGIONS" '.[$region].endpoints.kibana' /tmp/project_results.json`
export ELASTICSEARCH_PASSWORD=`jq -r --arg region "$REGIONS" '.[$region].credentials.password' /tmp/project_results.json`
export ES_URL=`jq -r --arg region "$REGIONS" '.[$region].endpoints.elasticsearch' /tmp/project_results.json`

agent variable set ES_KIBANA_URL `jq -r --arg region "$REGIONS" '.[$region].endpoints.kibana' /tmp/project_results.json`
agent variable set ES_USERNAME `jq -r --arg region "$REGIONS" '.[$region].credentials.username'  /tmp/project_results.json`
agent variable set ES_PASSWORD `jq -r --arg region "$REGIONS" '.[$region].credentials.password' /tmp/project_results.json`
agent variable set ES_DEPLOYMENT_ID `jq -r --arg region "$REGIONS" '.[$region].id' /tmp/project_results.json`

BASE64=$(echo -n "admin:${ELASTICSEARCH_PASSWORD}" | base64)
KIBANA_URL_WITHOUT_PROTOCOL=$(echo $KIBANA_URL | sed -e 's#http[s]\?://##g')


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
  #exit 1
fi

# Extract API key and validate it exists
ELASTICSEARCH_API_KEY=$(echo "$response_body" | jq -r '.encoded // empty')
if [ -z "$ELASTICSEARCH_API_KEY" ]; then
  echo "Error: Failed to extract API key from response"
  echo "Response: $response_body"
  #exit 1
fi

echo "API Key generated successfully"


# Update the JSON file with general api_key (with proper path creation)
if ! jq --arg region "$REGIONS" --arg apikey "$ELASTICSEARCH_API_KEY" \
  '.[$region] = (.[$region] // {}) |
   .[$region].credentials = (.[$region].credentials // {}) |
   .[$region].credentials.api_key = $apikey' \
  /tmp/project_results.json > /tmp/project_results.json.tmp; then
  echo "Error: Failed to update JSON with API key"
  #exit 1
fi
mv /tmp/project_results.json.tmp /tmp/project_results.json

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
    FLEET_URL=$(echo "$fleet_response" | jq -r '.items[0].host_urls[0] // empty')

    if [ -z "$FLEET_URL" ]; then
      echo "Warning: No Fleet Server URL found in response"
    else
      echo "Fleet URL: $FLEET_URL"

      # Update the JSON file with the Fleet URL
      if ! jq --arg region "$REGIONS" --arg fleet "$FLEET_URL" \
        '.[$region].endpoints = (.[$region].endpoints // {}) |
         .[$region].endpoints.fleet = $fleet' \
        /tmp/project_results.json > /tmp/project_results.json.tmp; then
        echo "Error: Failed to update JSON with Fleet URL"
        #exit 1
      fi
      mv /tmp/project_results.json.tmp /tmp/project_results.json
    fi
  fi
fi

echo "Configuration saved successfully to /tmp/project_results.json"

export JSON_FILE='/tmp/project_results.json'

get_project_results_json() {
    # Fetch project results and store in $JSON_FILE
    echo "Fetching project results from $JSON_FILE..."

    cat $JSON_FILE
    echo ""

    # Use jq to validate JSON and extract api_key, ES_URL, and KIBANA_URL
    # Get the first (and only) region key from the JSON
    API_KEY=$(jq -r 'to_entries[0].value.credentials.api_key' $JSON_FILE 2>/dev/null)
    ES_URL=$(jq -r 'to_entries[0].value.endpoints.elasticsearch' $JSON_FILE 2>/dev/null)
    KIBANA_URL=$(jq -r 'to_entries[0].value.endpoints.kibana' $JSON_FILE 2>/dev/null)
    FLEET_URL=$(jq -r 'to_entries[0].value.endpoints.fleet' $JSON_FILE 2>/dev/null)

    if [ $? -eq 0 ] && [ ! -z "$API_KEY" ] && [ "$API_KEY" != "null" ] && [ ! -z "$ES_URL" ] && [ "$ES_URL" != "null" ] && [ ! -z "$KIBANA_URL" ] && [ "$KIBANA_URL" != "null" ] || [ -z "$FLEET_URL" ] || [ "$FLEET_URL" = "null" ]; then
        echo "API key found successfully: ${API_KEY:0:10}..."
        echo "ES URL found: $ES_URL"
        echo "Kibana URL found: $KIBANA_URL"
        echo "Fleet URL found: $FLEET_URL"
        # Set agent variables
        echo "Setting agent variable ES_API_KEY..."
        agent variable set ES_API_KEY "$API_KEY"
        echo "Setting agent variable ES_URL..."
        agent variable set ES_URL "$ES_URL"
        echo "Setting agent variable KIBANA_URL..."
        agent variable set KIBANA_URL "$KIBANA_URL"
        echo "Setting agent variable FLEET_URL..."
        agent variable set FLEET_URL "$FLEET_URL"
        break
    else
        echo "API key, ES URL, or Kibana URL not found or invalid in response on attempt $attempt"
        [ $attempt -lt $MAX_RETRIES ] && echo "Waiting $RETRY_WAIT seconds before retry..." && sleep $RETRY_WAIT
    fi
}

create_env_file() {
    mkdir -p "/usr/share/nginx/html"
    # Write environment variables to $HOME/.env with export, extracting values directly with jq
    cat > "/usr/share/nginx/html/env" <<EOF
export APM_URL=$(jq -r '.[].endpoints.apm' "$JSON_FILE")
export ELASTICSEARCH_URL=$(jq -r '.[].endpoints.elasticsearch' "$JSON_FILE")
export INGEST_URL=$(jq -r '.[].endpoints.ingest' "$JSON_FILE")
export KIBANA_URL=$(jq -r '.[].endpoints.kibana' "$JSON_FILE")
export FLEET_URL=$(jq -r '.[].endpoints.fleet' "$JSON_FILE")
export ELASTICSEARCH_USER=$(jq -r '.[].credentials.username' "$JSON_FILE")
export ELASTICSEARCH_PASSWORD=$(jq -r '.[].credentials.password' "$JSON_FILE")
EOF
}

get_project_results_json
create_env_file

echo "Configure NGINX"
# Configure nginx
echo '
server {
  listen 8080 default_server;
  server_name kibana;
  location /nginx_status {
    stub_status on;
    allow 127.0.0.1;
    deny all;
  }
  
  location /env {
    alias /usr/share/nginx/html/env;
  }

  location / {
    proxy_set_header Host '${KIBANA_URL_WITHOUT_PROTOCOL}';
    proxy_pass '${KIBANA_URL}';
    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
    proxy_set_header Connection "";
    #proxy_hide_header Content-Security-Policy;
    proxy_set_header X-Scheme $scheme;
    proxy_set_header Authorization "Basic '${BASE64}'";
    proxy_set_header Accept-Encoding "";
    proxy_redirect off;
    proxy_http_version 1.1;
    client_max_body_size 20M;
    proxy_read_timeout 600;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains;";
    proxy_send_timeout          300;
    send_timeout                300;
    proxy_connect_timeout       300;
 }
}

server {
  listen 9200;
  server_name elasticsearch;

  location / {
    proxy_pass '${ES_URL}';
    proxy_connect_timeout       300;
    proxy_send_timeout          300;
    proxy_read_timeout          300;
    send_timeout                300;
  }
}
' > /etc/nginx/conf.d/default.conf

echo "Restart NGINX"
systemctl restart nginx
