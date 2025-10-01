RESOURCE_GROUP=tbekiares_group5
LOCATION=eastus2
CLUSTER_NAME=tbekiares-demo
TAGS="division=field org=sa team=pura project=tyronebekiares keep-until=2025-11-01"

#az group delete --name $RESOURCE_GROUP

#az group create --name $RESOURCE_GROUP --location $LOCATION --tags $TAGS

az feature register --name KubeletDefaultSeccompProfilePreview \
                    --namespace Microsoft.ContainerService
az provider register -n Microsoft.ContainerService

az aks delete \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME

az aks create \
    --tags $TAGS \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --vm-set-type VirtualMachineScaleSets \
    --node-count 1 \
    --os-sku AzureLinux \
    --nodepool-name "region1" \
    --kubelet-config ./linuxkubeletconfig.json \
    --node-vm-size Standard_D4d_v4 \
    --location $LOCATION \
    --load-balancer-sku standard \
    --generate-ssh-keys

az aks nodepool update \
    --tags $TAGS \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --name "region1" \
    --node-taints "REGION=1:PreferNoSchedule"

az aks nodepool add \
    --tags $TAGS \
    --resource-group $RESOURCE_GROUP \
    --cluster-name $CLUSTER_NAME \
    --name "region2" \
    --kubelet-config ./linuxkubeletconfig.json \
    --node-taints "REGION=2:PreferNoSchedule" \
    --node-count 1 \
    --os-sku AzureLinux \
    --node-vm-size Standard_D4d_v4

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

#------- TOOLS

source ../../k8s/tools/ksm.sh
