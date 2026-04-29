while getopts "h:i:j:" opt
do
   case "$opt" in
      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
   esac
done

enable_ramen() {
   printf "$FUNCNAME...\n"

   output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/internal/kibana/settings" \
      -w "\n%{http_code}" \
      -H 'kbn-xsrf: true' \
      -H 'x-elastic-internal-origin: Kibana' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      -H 'Content-Type: application/json' \
      -d '{"changes":{"elasticRamen:enabled": true}}')

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
enable_ramen

install_ramen() {
  printf "$FUNCNAME...\n"

  mkdir -p "/root/.config/elastic"
  cat > "/root/.config/elastic/config.yaml" <<EOF
current-context: default
contexts:
  default:
    elasticsearch_url: "$elasticsearch_es_endpoint"
    kibana_url: "$elasticsearch_kibana_endpoint"
    api_key: "$elasticsearch_api_key"
EOF

  cat > "/root/elastic_ramen.json" <<EOF
{
  "\$schema": "https://elastic.co/config.json",
  "provider": {
    "kibana": {
      "name": "Kibana LLM Gateway",
      "id": "kibana",
      "npm": "@ai-sdk/openai-compatible",
      "env": [],
      "models": {
        "default": {
          "id": "default",
          "name": "Default Connector",
          "attachment": false,
          "reasoning": false,
          "temperature": true,
          "tool_call": true,
          "release_date": "2025-01-01",
          "cost": {
            "input": 0,
            "output": 0
          },
          "limit": {
            "context": 128000,
            "output": 8192
          }
        }
      },
      "options": {
        "baseURL": "$elasticsearch_kibana_endpoint/internal/elastic_ramen/v1",
        "apiKey": "ignored",
        "headers": {
          "Authorization": "ApiKey $elasticsearch_api_key",
          "kbn-xsrf": "true",
          "x-elastic-internal-origin": "kibana",
          "elastic-api-version": "2023-10-31"
        }
      }
    }
  },
  "model": "kibana/default",
  "mcp": {
    "eab": {
      "type": "local",
      "command": [
        "elastic",
        "ab",
        "mcp",
        "proxy"
      ],
      "enabled": true
    }
  },
  "permission": {
    "eab_*": "allow"
  }
}
EOF

  curl -fsSL https://raw.githubusercontent.com/elastic/elastic-ramen/dev/install | bash

  printf "$FUNCNAME...SUCCESS\n"
}
install_ramen

