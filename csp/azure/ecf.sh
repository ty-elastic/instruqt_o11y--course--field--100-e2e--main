RESOURCE_GROUP=tbekiares_group5
LOCATION=eastus2
CLUSTER_NAME=tbekiares-demo
TAGS="division=field org=sa team=pura project=tyronebekiares keep-until=2025-11-01"

# Create the resource group to host the infrastructure
#az group delete --name $RESOURCE_GROUP
#az group create --name $RESOURCE_GROUP --location $LOCATION --tags $TAGS

while getopts "e:a:" opt
do
   case "$opt" in
      e ) elasticsearchOtlpEndpoint="$OPTARG" ;;
      a ) elasticsearchApiKey="$OPTARG" ;;
   esac
done

echo $elasticsearchOtlpEndpoint
echo $elasticsearchApiKey

# Deploy the infrastructure and the application
az deployment group create \
    --verbose --debug \
    --resource-group ${RESOURCE_GROUP} \
    --template-file infra/ecf.bicep \
    --parameters \
      elasticsearchOtlpEndpoint=$elasticsearchOtlpEndpoint \
      elasticsearchApiKey=$elasticsearchApiKey \
      logsDecoder=ds \
      metricsDecoder=dcr \
      eventHubPartitionCount=8 \
      eventHubMessageRetentionInDays=1 \
      version=0.6.0
