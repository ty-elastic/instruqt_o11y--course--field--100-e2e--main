@description('The name of the function app that you wish to create.')
param appName string = 'ecf${uniqueString(resourceGroup().id)}'

@description('Location of all resources. Defaults to the location of the resource group.')
param location string = resourceGroup().location

@description('Elasticsearch OTLP endpoint.')
param elasticsearchOtlpEndpoint string

@description('Elasticsearch API key.')
param elasticsearchApiKey string

@description('The decoder to use for logs. Available options: "ds" (diagnostic settings).')
param logsDecoder string = 'ds'

@description('The decoder to use for metrics. Available options: "ds" (diagnostic settings) and "dcr" (data collection rules). Defaults to "ds".')
param metricsDecoder string = 'ds'

@description('The version of the EDOT Cloud Forwarder (ECF) for Azure to deploy. Infrastructure and application versions are related.')
param version string = '0.6.0'

@description('The releases URL of the EDOT Cloud Forwarder (ECF) for Azure to deploy. Defaults official EDOT releases container.')
#disable-next-line no-hardcoded-env-urls // Direct URL to the releases container, SA for officiale releases is on a different tenant.
param releasesBaseUrl string = 'https://edotcfazure5gdoxpg7d2rim.blob.core.windows.net/releases'

@description('The capacity of the event hub namespace. Defaults to 1.')
@minValue(1)
@maxValue(10)
param eventHubNamespaceSkuCapacity int = 1

@description('The tier of the event hub namespace. Defaults to "Standard".')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param eventHubNamespaceSkuTier string = 'Standard'

@description('The partition count for the event hubs. Defaults to 4.')
@minValue(2)
param eventHubPartitionCount int = 4

@description('The message retention in days for the event hubs. Defaults to 1.')
param eventHubMessageRetentionInDays int = 1

@description('Whether the exporter sending queue is enabled. Defaults to false.')
param exporterSendingQueueEnabled bool = false

@description('Whether the exporter retry on failure is enabled. Defaults to true.')
param exporterRetryOnFailureEnabled bool = true

@description('The name of the deployment storage container. Defaults to "app-package".')
param storageAccountDeploymentContainerName string = 'app-package-${appName}'

@description('The minimum TLS version for the storage account. Defaults to "TLS1_2".')
param storageAccountMinimumTlsVersion string = 'TLS1_2'

@description('The access tier for the storage account. Defaults to "Hot".')
param storageAccountAccessTier string = 'Hot'

@description('The maximum instance count for the function app. Defaults to 40.')
@minValue(40)
param functionAppMaximumInstanceCount int = 40

@description('The instance memory for the function app. Defaults to 2048.')
@allowed([
  512
  2048
  4096
])
param functionAppInstanceMemoryMB int = 512

@description('The runtime version for the function app. Defaults to "1.0".')
param functionAppRuntimeVersion string = '1.0'

// ------------------------------------------------------------------------------------------------
// Event Hub resources
// ------------------------------------------------------------------------------------------------

@description('Event Hub namespace that hosts all event hubs.')
resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: appName
  location: location
  sku: {
    name: eventHubNamespaceSkuTier
    tier: eventHubNamespaceSkuTier
    capacity: eventHubNamespaceSkuCapacity
  }
}

resource logsEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  name: 'logs'
  parent: eventHubNamespace
  properties: {
    messageRetentionInDays: eventHubMessageRetentionInDays
    partitionCount: eventHubPartitionCount
  }
}

resource metricsEventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  name: 'metrics'
  parent: eventHubNamespace
  properties: {
    messageRetentionInDays: eventHubMessageRetentionInDays
    partitionCount: eventHubPartitionCount
  }
}

resource logsEventHubConsumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2024-01-01' = {
  name: 'ecf'
  parent: logsEventHub
}

resource metricsEventHubConsumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2024-01-01' = {
  name: 'ecf'
  parent: metricsEventHub
}

resource eventHubAuthorization 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = {
  name: 'ecf'
  parent: eventHubNamespace
  properties: {
    rights: [
      // we only need to listen to events
      'Listen'
    ]
  }
}

resource cliEventHubAuthorization 'Microsoft.EventHub/namespaces/authorizationRules@2024-01-01' = {
  name: 'cli-tools'
  parent: eventHubNamespace
  properties: {
    rights: [
      // we only use this for testing; remove this if this
      // project moves beyond the prototype stage.
      'Listen'
      'Send'
    ]
  }
}

// ------------------------------------------------------------------------------------------------
// Storage Account resources
// ------------------------------------------------------------------------------------------------

var storageAccountName = '${uniqueString(resourceGroup().id)}ecf'

var containers = [
  {
    name: storageAccountDeploymentContainerName
    publicAccess: 'None'
  }
]

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }

  resource blobServices 'blobServices' = if (!empty(containers)) {
    name: 'default'
    properties: {
      accessTier:  storageAccountAccessTier
      allowBlobPublicAccess: false
      allowCrossTenantReplication: true
      allowSharedKeyAccess: false
      defaultToOAuthAuthentication: false
      dnsEndpointType: 'Standard'
      minimumTlsVersion: storageAccountMinimumTlsVersion
      networkAcls: {
        bypass: 'AzureServices'
        defaultAction: 'Allow'
      }
      publicNetworkAccess: 'Enabled'
      retentionPolicy: {}
    }

    resource container 'containers' = [for container in containers: {
      name: container.name
      properties: {
        publicAccess: contains(container, 'publicAccess') ? container.publicAccess : 'None'
      }
    }]
  }  
}

// ------------------------------------------------------------------------------------------------
// Azure Function App resources
// ------------------------------------------------------------------------------------------------

resource hostingPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${uniqueString(resourceGroup().id)}-plan'
  location: location
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  properties: {
    // If Linux app service plan true, false otherwise.
    // https://learn.microsoft.com/en-us/azure/templates/microsoft.web/serverfarms?pivots=deployment-language-bicep
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: '${uniqueString(resourceGroup().id)}-app'
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccount.name
        }        
        {
          name: 'EventHubConnectionString'
          value: 'Endpoint=sb://${eventHubNamespace.name}.servicebus.windows.net/;SharedAccessKeyName=${eventHubAuthorization.name};SharedAccessKey=${eventHubAuthorization.listKeys().primaryKey}'
        }
        {
          name: 'ELASTICSEARCH_OTLP_ENDPOINT'
          value: elasticsearchOtlpEndpoint
        }
        {
          name: 'ELASTICSEARCH_API_KEY'
          value: elasticsearchApiKey
        }
        {
          name: 'LOGS_DECODER'
          value: logsDecoder
        }
        {
          name: 'METRICS_DECODER'
          value: metricsDecoder
        }
        {
          name: 'EXPORTER_SENDING_QUEUE_ENABLED'
          value: exporterSendingQueueEnabled ? 'true' : 'false'
        }
        {
          name: 'EXPORTER_RETRY_ON_FAILURE_ENABLED'
          value: exporterRetryOnFailureEnabled ? 'true' : 'false'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }        
      ]
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}${storageAccountDeploymentContainerName}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: functionAppMaximumInstanceCount
        instanceMemoryMB: functionAppInstanceMemoryMB
        triggers: {
          http: {}
        }
      }
      runtime: { 
        name: 'custom'
        version: functionAppRuntimeVersion
      }
    }    
  }
}

// Function App permissions
// ========================

var storageRoleDefinitionId  = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' //Storage Blob Data Owner role

// Allow access from function app to storage account using a managed identity
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, storageRoleDefinitionId, appName)
  scope: storageAccount
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageRoleDefinitionId)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Extensions to deploy the function app from a remote package
// ==========================================================

// Deploy the OneDeploy extension to the Function App
// This extension allows us to deploy the function app from a remote package.
// https://learn.microsoft.com/en-us/azure/templates/microsoft.web/sites/extensions-onedeploy?pivots=deployment-language-bicep
resource functionOneDeploy 'Microsoft.Web/sites/extensions@2024-04-01' = {
  parent: functionApp
  name: 'onedeploy'
  properties: {
    packageUri: '${releasesBaseUrl}/v${version}/ecf-${version}.zip'
    remoteBuild: false
  }
}


// ------------------------------------------------------------------------------------------------
// Application Insights resources
// ------------------------------------------------------------------------------------------------

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

