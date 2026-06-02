
retry_script="$PWD/assets/scripts/retry.sh"

OPTIND=1
while getopts "r:" opt
do
   case "$opt" in
      r ) retry_script="$OPTARG" ;;
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
   if [ "$http_code" != "200" ]; then
      printf "$FUNCNAME...ERROR $http_code: $http_response\n"
      return 1
   fi
   printf "$FUNCNAME...SUCCESS\n"
   return 0
}
retry_command_lin finalize
