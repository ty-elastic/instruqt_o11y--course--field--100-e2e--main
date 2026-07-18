
root="../../"
http_auth=true

OPTIND=1
while getopts "s:7:" opt
do
   case "$opt" in
      s ) root="$OPTARG" ;;
      7 ) http_auth="$OPTARG" ;; 
   esac
done


helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  -f $root/utils/traefik/values.yaml

HTTP_PASSWORD=$(openssl rand -base64 12)
kubectl create secret generic traefik-auth --namespace=traefik \
  --from-literal=username=admin \
  --from-literal=password=$HTTP_PASSWORD

kubectl delete secret --namespace=traefik traefik-auth-encoded
htpasswd -b -c .htpasswd admin $HTTP_PASSWORD
kubectl create secret generic traefik-auth-encoded --from-file=.htpasswd --namespace=traefik
rm -rf .htpasswd

if [ "$http_auth" = "true"  ]; then
  kubectl apply -f $root/utils/traefik/auth.yaml
else
  kubectl apply -f $root/utils/traefik/noauth.yaml
fi
