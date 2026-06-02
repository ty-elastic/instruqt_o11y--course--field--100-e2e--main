
retry_script="$PWD/assets/scripts/retry.sh"
repo=us-central1-docker.pkg.dev/elastic-sa/tbekiares
course=latest

OPTIND=1
while getopts "s:c:r:i:j:h:" opt
do
   case "$opt" in
      s ) retry_script="$OPTARG" ;;
      c ) course="$OPTARG" ;;
      r ) repo="$OPTARG" ;;

      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
   esac
done

source $retry_script

get_lb_address() {
   printf "$FUNCNAME...\n"
    export SERVICE_IP=$(kubectl -n $1 get service $2 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export SERVICE_PORT=$(kubectl -n $1 get service $2 -o jsonpath='{.spec.ports[0].port}')
    if [ -z "$SERVICE_IP" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi
   printf "$FUNCNAME...SUCCESS $SERVICE_IP $SERVICE_PORT\n"
   return 0
}

helm repo add requarks https://charts.js.wiki
kubectl create namespace wiki
helm install wiki \
    --namespace wiki \
    --set postgresql.persistence.enabled=false \
    --set postgresql.image.repository=$repo/postgresql \
    --set postgresql.image.tag=$course \
    --set postgresql.image.pullPolicy=Always \
    --set ingress.enabled=false \
    requarks/wiki

kubectl apply -f service.yaml -n wiki

# wait
kubectl wait --for=condition=Ready pods --all -n wiki --timeout=120s

finalize() {
   printf "$FUNCNAME...\n"
   get_lb_address wiki wiki-ext

   output=$(curl -s -X POST "http://$SERVICE_IP:$SERVICE_PORT/finalize" \
         -w "\n%{http_code}" \
         -H 'Content-Type: application/json' \
         -d '{
            "adminEmail": "admin@example.com",
            "adminPassword": "password123",
            "adminPasswordConfirm": "password123",
            "siteUrl": "http://'$SERVICE_IP':'$SERVICE_PORT'",
            "telemetry": false
        }')

   # Extract HTTP status code
   http_code=$(echo "$output" | tail -n1)
   http_response=$(echo "$output" | sed '$d')
   if [[ "$http_code" != "200" && "$http_code" != "404" ]]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi
   printf "$FUNCNAME...SUCCESS\n"
   return 0
}
retry_command_lin finalize

create_wiki_connector() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_es_endpoint/_connector" \
         -w "\n%{http_code}" \
         -H "Authorization: ApiKey ${elasticsearch_api_key}" \
         -H 'Content-Type: application/json' \
         -d '{"description":"wiki content","index_name":"wiki","is_native":false,"name":"wiki","service_type":"postgresql"}')

   # Extract HTTP status code
   http_code=$(echo "$output" | tail -n1)
   http_response=$(echo "$output" | sed '$d')
   if [[ "$http_code" != "201" && "$http_code" != "400" ]]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi

   CONNECTOR_ID=$(echo $http_response | jq -r '.id')

   printf "$FUNCNAME...SUCCESS id=$CONNECTOR_ID\n"
   return 0
}
retry_command_lin create_wiki_connector

export CONNECTOR_ID=$CONNECTOR_ID
envsubst '$elasticsearch_es_endpoint,$elasticsearch_api_key,$CONNECTOR_ID' < connector.yaml | kubectl apply -f -
kubectl -n wiki rollout restart deployment/connector

create_wiki_config() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/internal/content_connectors/connectors/$CONNECTOR_ID/configuration" \
         -w "\n%{http_code}" \
         -H 'kbn-xsrf: true' \
         -H 'x-elastic-internal-origin: Kibana' \
         -H "Authorization: ApiKey ${elasticsearch_api_key}" \
         -H 'Content-Type: application/json' \
         -d '{"fetch_size":"","retry_count":"","host":"wiki-postgresql","port":5432,"username":"postgres","password":"postgres","database":"wiki","schema":"public","tables":"pages","ssl_enabled":false}')

   # Extract HTTP status code
   http_code=$(echo "$output" | tail -n1)
   http_response=$(echo "$output" | sed '$d')
   if [ "$http_code" != "200" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi

   printf "$FUNCNAME...SUCCESS\n"
   return 0
}
retry_command_lin create_wiki_config


#!/bin/bash

# Define endpoint and credentials
API_URL="http://$SERVICE_IP:$SERVICE_PORT/graphql"

enable_api() {
   printf "$FUNCNAME...\n"
   # Define the raw GraphQL query text
   gql_query='
   mutation ($username: String!, $password: String!, $strategy: String!) {
      authentication {
         login(username: $username, password: $password, strategy: $strategy) {
            responseResult {
               succeeded
               errorCode
               slug
               message
               __typename
            }
            jwt
            mustChangePwd
            mustProvideTFA
            mustSetupTFA
            continuationToken
            redirect
            tfaQRImage
            __typename
         }
         __typename
      }
   }'

   # Define variables as a JSON string
   gql_variables='{"username":"admin@example.com","password":"password123","strategy":"local"}'

   # Build payload and execute request
   curl -s -X POST "$API_URL" \
   -H "Content-Type: application/json" \
   -d "$(jq -n --arg q "$gql_query" --argjson v "$gql_variables" '{query: $q, variables: $v}')"
}
enable_api