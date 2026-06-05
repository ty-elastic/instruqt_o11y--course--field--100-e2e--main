
values="values.yaml"

OPTIND=1
while getopts "v:" opt
do
   case "$opt" in
      v ) values="$OPTARG" ;;
   esac
done

echo $values

kubectl create namespace infra

kubectl create -f 'https://strimzi.io/install/latest?namespace=infra' -n infra
kubectl wait --for=condition=Ready pod --all -n infra --timeout=300s

kubectl apply -f $values -n infra 
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n infra
