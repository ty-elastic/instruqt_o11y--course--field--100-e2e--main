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

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  tags: {
    org: 'sa'
    division: 'field'
    team: 'pura'
    'keep-until': '2025-11-01'
    project: 'tyronebekiares'
  }
}

// ------------------------------------------------------------------------------------------------
// Azure Function App resources
// ------------------------------------------------------------------------------------------------

resource hostingPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${uniqueString(resourceGroup().id)}-plan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    // If Linux app service plan true, false otherwise.
    // https://learn.microsoft.com/en-us/azure/templates/microsoft.web/serverfarms?pivots=deployment-language-bicep
    reserved: true
  }
  tags: {
    org: 'sa'
    division: 'field'
    team: 'pura'
    'keep-until': '2025-11-01'
    project: 'tyronebekiares'
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: '${uniqueString(resourceGroup().id)}-app'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'custom'
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
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '${releasesBaseUrl}/v${version}/ecf-${version}.zip'
        }
      ]
    }
  }
  tags: {
    org: 'sa'
    division: 'field'
    team: 'pura'
    'keep-until': '2025-11-01'
    project: 'tyronebekiares'
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
  tags: {
    org: 'sa'
    division: 'field'
    team: 'pura'
    'keep-until': '2025-11-01'
    project: 'tyronebekiares'
  }
}

// // ------------------------------------------------------------------------------------------------
// // Data Collection Rules (DCR) resources
// // ------------------------------------------------------------------------------------------------

// // Create a Data Collection Rule to collect metrics from the Storage Account for
// // demonstration purposes.
// resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
//   name: '${uniqueString(resourceGroup().id)}-dcr'
//   location: location
//   kind: 'PlatformTelemetry'
//   identity:{
//     type: 'SystemAssigned'
//   }
//   properties: {
//     dataSources: {
//       platformTelemetry:[
//         {
//           name: 'myPlatformTelemetryDataSource'
//           streams:[
//             'Microsoft.storage/storageaccounts:Metrics-Group-All'
//             'Microsoft.storage/Storageaccounts/blobservices:Metrics-Group-All'
//             'Microsoft.storage/storageaccounts/fileservices:Metrics-Group-All'
//             'Microsoft.storage/storageaccounts/queueservices:Metrics-Group-All'
//             'Microsoft.storage/storageaccounts/tableservices:Metrics-Group-All'
//           ]
//         }
//       ]
//     }
//     destinations:{
//       eventHubs: [
//         {
//           name: 'metricsEventHubDestination'
//           eventHubResourceId: metricsEventHub.id
//         }
//       ]
//     }
//     dataFlows: [
//       {
//         streams: [
//           'Microsoft.storage/storageaccounts:Metrics-Group-All'
//           'Microsoft.storage/Storageaccounts/blobservices:Metrics-Group-All'
//           'Microsoft.storage/storageaccounts/fileservices:Metrics-Group-All'
//           'Microsoft.storage/storageaccounts/queueservices:Metrics-Group-All'
//           'Microsoft.storage/storageaccounts/tableservices:Metrics-Group-All'
//         ]
//         destinations:[
//           'metricsEventHubDestination'
//         ]
//       }
//     ]
//   }
// }

// // Assign the 'Azure Event Hubs Data Sender' role to systen assigned identity, so 
// // the Data Collection Rule can send data to the Event Hub.
// resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
//   name: guid(resourceGroup().id, dataCollectionRule.name, 'Azure Event Hubs Data Sender')
//   scope: eventHubNamespace
//   properties: {
//     principalId: dataCollectionRule.identity.principalId
//     principalType: 'ServicePrincipal'
//     // TODO: I am not sure if this is the best way to get the role definition ID 🤔
//     // I looked up '2b629674-e913-4c01-ae53-ef4638d8f975' browsing the roles in the
//     // Azure portal. I'm still not familiar with Bicep. Let's stick with this for now.
//     //
//     // We DCR needs the 'Azure Event Hubs Data Sender' role to send data to the Event Hub.
//     roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2b629674-e913-4c01-ae53-ef4638d8f975')
//   }
// }

// // Associate the Data Collection Rule with the Storage Account, so it can
// // collect data from the Storage Account.
// //
// // We associate the DCR with the Storage Account to have a quick way to
// // collect metrics for demonstration purposes.
// resource storageAccountDcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2021-09-01-preview' = {
//   name: '${uniqueString(resourceGroup().id)}-storageDCRAssociation'
//   properties: {
//     dataCollectionRuleId: dataCollectionRule.id
//   }
//   scope: storageAccount
// }
