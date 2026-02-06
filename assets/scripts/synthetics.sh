source assets/scripts/retry.sh

while getopts "n:h:i:j:k:" opt
do
   case "$opt" in
      n ) namespace="$OPTARG" ;;

      h ) elasticsearch_kibana_endpoint="$OPTARG" ;;
      i ) elasticsearch_api_key="$OPTARG" ;;
      j ) elasticsearch_es_endpoint="$OPTARG" ;;
      k ) elasticsearch_otlp_endpoint="$OPTARG" ;;
   esac
done

export AGENT_VERSION=9.3.0

####################################################################### CREATE POLICY
POLICY_NUM=0

create_policy() {
    ((POLICY_NUM++))

    output=$(curl -s -X POST "$elasticsearch_kibana_endpoint/api/fleet/agent_policies?sys_monitoring=false" \
      --header 'Content-Type: application/json' \
      -H "Authorization: ApiKey ${elasticsearch_api_key}" \
      --header 'kbn-xsrf: true' \
      --data '{
      "name": "Synthetics '$POLICY_NUM'",
      "description": "",
      "namespace": "default",
      "monitoring_enabled": [
        "logs",
        "metrics"
      ]
    }')

    #echo $output
    POLICY_ID=$(echo $output | jq -r '.item.id')
    echo $POLICY_ID

    if [ "${POLICY_ID}" = "null" ]; then
        echo "agent: fleet not ready on attempt $attempt: $output"
        return 1
    else
        echo "agent: agent policy created on $attempt"
        return 0
    fi
}
retry_command_lin create_policy

output=$(curl -s -X GET "$elasticsearch_kibana_endpoint/api/fleet/enrollment_api_keys" \
  --header 'Content-Type: application/json' \
  -H "Authorization: ApiKey ${elasticsearch_api_key}" \
  --header 'kbn-xsrf: true')
#echo $output

ENROLLMENT=$(echo $output | jq -r '.items[] | select (.policy_id == "'$POLICY_ID'")')
#echo $ENROLLMENT

ENROLLMENT_ID=$(echo $ENROLLMENT | jq -r '.id')
ENROLLMENT_API_KEY_ID=$(echo $ENROLLMENT | jq -r '.api_key_id')
export ENROLLMENT_API_KEY=$(echo $ENROLLMENT | jq -r '.api_key')

echo $ENROLLMENT_ID
echo $ENROLLMENT_API_KEY_ID
echo $ENROLLMENT_API_KEY

# ------------- START AGENT

envsubst < agents/synthetics/synthetics.yaml | kubectl apply -f -

# ------------- CREATE PRIVATE MONITOR

curl \
 -X POST "$elasticsearch_kibana_endpoint/api/synthetics/private_locations" \
 -H "Authorization: ApiKey ${elasticsearch_api_key}" \
 --header "Content-Type: application/json" \
 --header 'kbn-xsrf: true' \
 --data '{
    "label": "host-1",
    "agentPolicyId": "'$POLICY_ID'",
    "geo": {
      "lat": 0,
      "lon": 0
    },
    "spaces": [
      "*"
    ]
}'
