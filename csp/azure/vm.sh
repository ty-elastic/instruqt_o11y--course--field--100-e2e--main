RESOURCE_GROUP=tbekiares_group5
LOCATION=eastus2
CLUSTER_NAME=tbekiares-demo
TAGS="division=field org=sa team=pura project=tyronebekiares keep-until=2025-11-01"

vmname="tbekiares_vm"
username="azureuser"

az vm create \
      --tags $TAGS \
      --resource-group $RESOURCE_GROUP \
      --name $vmname \
      --image Ubuntu2204 \
      --admin-username azureuser \
      --generate-ssh-keys \
      --public-ip-sku Standard \
      --nsg aviatrix-global-vpn-nsg-template
      