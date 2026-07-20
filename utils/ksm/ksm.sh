if kubectl get deployments --all-namespaces -l app.kubernetes.io/name=kube-state-metrics | grep -q "kube-state-metrics"; then
    echo "kube-state-metrics is already installed. Skipping installation."
else
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    helm install --set namespaceOverride=kube-system kube-state-metrics prometheus-community/kube-state-metrics
fi
