
values="values.yaml"

OPTIND=1
while getopts "v:" opt
do
   case "$opt" in
      v ) values="$OPTARG" ;;
   esac
done

echo $values

kubectl create namespace kafka

kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka
kubectl wait --for=condition=Ready pod --all -n kafka --timeout=300s

kubectl apply -f $values -n kafka 
kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n kafka
