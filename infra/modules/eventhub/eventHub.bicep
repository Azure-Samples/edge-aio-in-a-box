/*region Header
      Module Steps 
      1 - Create EventHub Namespace and EventHub Instance
      2 - Create Consumer Group
*/

//Declare Parameters--------------------------------------------------------------------------------------------------------------------------
param location string = resourceGroup().location
param eventHubNamespaceName string
param eventHubName string
param tags object = {}

@description('Specifies the messaging tier for Event Hub Namespace.')
@allowed([
  'Basic'
  'Standard'
])
param eventHubSku string = 'Standard'

param consumergroupeNames array = [
  'adx-cg'
  'databricks-cg'
  'dotnet-cg'
  'fabric-cg'
  'iotexplorer-cg'
  'realtime-cg'
  'servicebusexplorer-cg'
  'streaminganalytics-cg'
  'vscode-cg'
]

//https://learn.microsoft.com/en-us/azure/templates/microsoft.eventhub/namespaces/eventhubs
resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: eventHubSku
    tier: eventHubSku
    capacity: 1
  }
  properties: {
    // disableLocalAuth: false
    isAutoInflateEnabled: true
    maximumThroughputUnits: 1
    minimumTlsVersion: '1.2'
  }
  tags: tags
}

//
resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: 1
    partitionCount: 1
    retentionDescription: {
      cleanupPolicy: 'Delete'
    }
  }
}

//2. Create Consumer Group(s)
//https://learn.microsoft.com/en-us/azure/templates/microsoft.eventhub/namespaces/eventhubs/consumergroups
resource consumerGroups 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2024-01-01' = [for cg in consumergroupeNames: {
  parent: eventHub
  name: cg
  properties: {}
}]


//Enable all logs and metrics
//Create a diagnostic setting to send IoT Hub logs and metrics to log analytics workspace
// resource eventHubDiagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: 'Diag-iot-hub'
//   scope: eventHubNamespace
//   properties: {
//     workspaceId: logAnalyticsWorkspace.id
//     logs: [
//       {
//         categoryGroup: 'allLogs'
//         enabled: true
//       }
//       {
//         categoryGroup: 'audit'
//         enabled: true
//       }      
//     ]
//     metrics: [
//       {
//         category: 'AllMetrics'
//         enabled: true
//       }
//     ]
//   }
// }

output eventHubNamespaceName string = eventHubNamespace.name
output eventHubName string = eventHub.name
