source /opt/workshops/elastic-retry.sh
export $(curl http://kubernetes-vm:9000/env | xargs)

helm repo add elastic https://helm.elastic.co

helm install --create-namespace -n=trading-1 universal-profiling-agent --set "projectID=1,secretToken=abc123" --set "collectionAgentHostPort=kubernetes-vm:8260" --set "disableTLS=true" --version=9.2.2 elastic/profiling-agent
