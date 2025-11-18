helm uninstall -n kestra kestra
kubectl create namespace kestra
helm install --namespace kestra kestra kestra/kestra-starter -f values.yaml
