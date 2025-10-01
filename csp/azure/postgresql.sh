RESOURCE_GROUP=tbekiares_group5
LOCATION=eastus2
CLUSTER_NAME=tbekiares-demo
TAGS="division=field org=sa team=pura project=tyronebekiares keep-until=2025-11-01"

while getopts "p:" opt
do
   case "$opt" in
      p ) password="$OPTARG" ;;
   esac
done

 az postgres flexible-server create \
      --tags $TAGS \
      --resource-group $RESOURCE_GROUP \
      --name tbekiarestrades \
      --location $LOCATION \
      --admin-user tbekiaresadmin \
      --admin-password $password \
      --sku-name standard_b1ms \
      --tier Burstable \
      --storage-size 64 \
      --version 17

az postgres flexible-server db create --resource-group $RESOURCE_GROUP --server-name tbekiarestrades --database-name trades

az postgres flexible-server parameter set --resource-group $RESOURCE_GROUP --server-name tbekiarestrades --name azure.extensions --value pg_stat_statements

az postgres flexible-server firewall-rule create --resource-group $RESOURCE_GROUP --name tbekiarestrades --rule-name allowazureservices --start-ip-address 0.0.0.0

