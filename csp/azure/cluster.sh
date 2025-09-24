RESOURCE_GROUP=tbekiares_group5
LOCATION=eastus2
CLUSTER_NAME=tbekiares-demo
TAGS="division=field org=sa team=pura project=tyronebekiares keep-until=2025-11-01"

#az group delete --name $RESOURCE_GROUP

az group create --name $RESOURCE_GROUP --location $LOCATION --tags $TAGS

# az aks delete \
#     --resource-group $RESOURCE_GROUP \
#     --name $CLUSTER_NAME

az aks create \
    --tags $TAGS \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --vm-set-type VirtualMachineScaleSets \
    --node-count 1 \
    --nodepool-name "region1" \
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
    --node-taints "REGION=2:PreferNoSchedule" \
    --node-count 1 \
    --node-vm-size Standard_D4d_v4

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

# az deployment group create \
#     --verbose --debug \
#     --resource-group ${RESOURCE_GROUP} \
#     --template-file template.json \
#     --parameter-file parameters.json

# az aks get-credentials --resource-group tbekiares_group3 --name trading --overwrite-existing

#------- TOOLS

source ../../k8s/tools/ksm.sh
