helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install --set namespaceOverride=kube-system kube-state-metrics prometheus-community/kube-state-metrics
