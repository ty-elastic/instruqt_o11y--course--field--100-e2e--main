source /workspace/workshop/instruqt/scripts/retry.sh

AGENT_VERSION=9.2.2

####################################################################### CREATE POLICY
POLICY_NUM=0

create_policy() {
    ((POLICY_NUM++))

    output=$(curl -s -X POST "$KIBANA_URL/api/fleet/agent_policies?sys_monitoring=false" \
      --header 'Content-Type: application/json' \
      --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
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

output=$(curl -s -X GET "$KIBANA_URL/api/fleet/enrollment_api_keys" \
  --header 'Content-Type: application/json' \
  --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
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

envsubst < /workspace/workshop/instruqt/scripts/synthetics.yaml | kubectl apply -f -

# ------------- CREATE PRIVATE MONITOR

curl \
 -X POST "$KIBANA_URL/api/synthetics/private_locations" \
 --header "Authorization: Basic $ELASTICSEARCH_AUTH_BASE64" \
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


