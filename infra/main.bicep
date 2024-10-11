/*region Header
      =========================================================================================================
      Created by:       Author: Your Name | your.name@azurestream.io
      Description:      AIO with AI in-a-box - Deploy your AI Model on the Edge with Azure IoT Operations
      =========================================================================================================

      Dependencies:
        Install Azure CLI
        https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest

        Install Latest version of Bicep
        https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install

        To Run terminal to the root folder of this repository and run the following command:
        azd auth login --use-device-code
        az login --use-device-code 
        az account set --subscription <subscription id>

        azd up
      //=====================================================================================

*/
targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param resourceGroupName string = ''

var abbrs = loadJsonContent('abbreviations.json')
var uniqueSuffix = substring(uniqueString(subscription().id, resourceGroup.id), 1, 3)
param tags object

//UAMI Module Parameters
param msiName string = ''

//Key Vault
var keyVaultName = ''

@description('Your Service Principal Object ID or your own User Object ID so you can give the SP access to the Key Vault Secrets')
param spObjectId string = '' //This is your Service Principal Object ID or your own User Object ID so you can give the SP access to the Key Vault Secrets

@description('Service Principal App ID')
param spAppId string = ''

@description('Service Principal Secret')
@secure()
param spSecret string = ''

@description('Your Service Principal App Object ID')
param spAppObjectId string = '' //This is your App Registration Object ID


//VNet Module Parameters
var networkSecurityGroupName = '' //'${virtualMachineName}-nsg'
var subnetName = 'AIO-Subnet'
var publicIPAddressName = '' //'${virtualMachineName}-PublicIP'

@sys.description('Virtual Nework Name. This is a required parameter to build a new VNet or find an existing one.')
param vNetName string = 'aiobx-vnet'

@sys.description('Virtual Network Address Space.')
param vNetAddressSpace array = ['10.7.0.0/16']

@sys.description('AIO Subnet Address Space.')
param subnetCIDR string = '10.7.0.0/24'


//VM Module Parameters
@sys.description('VM size, please choose a size which have enough memory and CPU for K3s.')
param virtualMachineSize string  //'Standard_D8s_v4'-Make sure the VM size you pick has at least 8GBs of memory

@sys.description('Ubuntu K3s Cluster Name')
param virtualMachineName string

@sys.description('Arc for Kubernates Cluster Name')
param arcK8sClusterName string

@description('Username for the Virtual Machine.')
param adminUsername string

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'password'
])
param authenticationType string


@sys.description('URI for K3s VM Configuraiton Script')
param scriptURI string = 'https://raw.githubusercontent.com/Azure-Samples/edge-aio-in-a-box/main/scripts/'

@sys.description('Shell Script to be executed')
param ShellScriptName string = 'azd_configureAIO-0.7.sh'

@sys.description('Custom Locations RP ObjectID')
param customLocationRPSPID string = ''

//Storage Account
var storageAccountName = ''

//Log Analytics Workspace
@description('The log analytics workspace name. If ommited will be generated')
param logAnalyticsWorkspaceName string = ''

//Application Insights
param useApplicationInsights bool = true
var applicationInsightsName = ''

//ACR Module Parameters
param acrName string = ''
@description('The SKU to use for the Azure Container Registry.')
param acrSku string = 'Standard'

//EventHub Namespace
@description('The EventHub Namespace Name. If ommited will be generated')
param eventHubNamespaceName string = ''
@description('The EventHub Name. If ommited will be generated')
param eventHubName string = ''

//AI Studio Hub
@minLength(2)
@maxLength(12)
@description('Name for the AI resource and used to derive name of dependent resources.')
param aiHubName string = 'aiobx'

@description('Description of your Azure AI resource dispayed in AI studio')
param aiHubDescription string = 'This is an example AI resource for use in Azure AI Studio.'

// Variables
var name = toLower('${aiHubName}')
var aiConfig = loadYamlContent('./ai.yaml')

//Azure ML
var workspaceName = ''
@description('Specifies the name of the Azure Machine Learning workspace Compute Name.')
param amlcompclustername string = 'aml-cluster'
@description('Specifies the name of the Azure Machine Learning workspace Compute Name.')
param amlcompinstancename string = ''
@description('Specifies whether to reduce telemetry collection and enable additional encryption.')
param hbi_workspace bool = false
@description('Identity type of storage account services for your azure ml workspace.')
param systemDatastoresAuthMode string = 'accessKey'

// Generate a unique token to be used in naming resources.
// Remove linter suppression after using.
#disable-next-line no-unused-vars
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))


//====================================================================================
// Create Resource Group
//====================================================================================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

//2. Create UAMI
module m_msi 'modules/identity/msi.bicep' = {
  name: 'deploy_msi'
  scope: resourceGroup
  params: {
    location: location
    msiName: !empty(msiName) ? msiName : '${abbrs.managedIdentityUserAssignedIdentities}${environmentName}-${uniqueSuffix}'
    tags: tags
  }
}

//3. Create KeyVault used for Azure IoT Operations
//https://docs.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults
module m_kvn 'modules/keyvault/keyvault.bicep' = {
  name: 'deploy_keyvault'
  scope: resourceGroup
  params: {
    keyVaultName: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${environmentName}-${uniqueSuffix}'
    location: location
    vmUserAssignedIdentityPrincipalID: m_msi.outputs.msiPrincipalID

    //Send in Service Principal and/or User Oject ID
    spObjectId: spObjectId
  }
}

//4. Create Required Storage Account(s)
//Deploy Storage Accounts (Create your Storage Account for your ML and AI Studio Workspace)
//https://docs.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts
module m_stg 'modules/storage/storage-account.bicep' = {
  name: 'deploy_storageaccount'
  scope: resourceGroup
  params: {
    storageAccountName: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${environmentName}${uniqueSuffix}'
  }
}

//5. Create Log Analytics Workspace
//https://learn.microsoft.com/en-us/azure/templates/microsoft.insights/components?pivots=deployment-language-bicep
module m_loga 'modules/aml/loganalytics.bicep' = {
  name: 'deploy_loganalytics'
  scope: resourceGroup
  params: {
    location: location
    logAnalyticsName: !useApplicationInsights ? '': !empty(logAnalyticsWorkspaceName) ? logAnalyticsWorkspaceName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    tags: tags
  }
}

//6. Create Application Insights Instance
//https://learn.microsoft.com/en-us/azure/templates/microsoft.insights/components?pivots=deployment-language-bicep
module m_aisn 'modules/aml/applicationinsights.bicep' = {
  name: 'deploy_appinsights'
  scope: resourceGroup
  params: {
    location: location
    applicationInsightsName:  !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${environmentName}-${uniqueSuffix}'
    logAnalyticsWorkspaceId: m_loga.outputs.id
  }
}

//7. Create Azure Container Registry
//https://learn.microsoft.com/en-us/azure/templates/microsoft.machinelearningservices/workspaces?pivots=deployment-language-bicep
module m_acr './modules/aml/acr.bicep' = {
  name: 'deploy_acr'
  scope: resourceGroup
  params: {
    location: location
    acrName: !empty(acrName) ? acrName : '${abbrs.containerRegistryRegistries}${environmentName}${uniqueSuffix}'
    acrSku: acrSku
    tags: tags
  }
}

//Create Azure Event Hub for AIO Data Flows
module eventhub 'modules/eventHub/eventHub.bicep' = {
  name: 'deploy_eventhub'
  scope: resourceGroup
  params: {
    eventHubNamespaceName:  !empty(eventHubNamespaceName) ? eventHubNamespaceName : '${abbrs.eventHubNamespaces}${arcK8sClusterName}'
    eventHubName:  !empty(eventHubName) ? eventHubName : '${abbrs.eventHubNamespacesEventHubs}${arcK8sClusterName}'
  }
}

//Create Dependent resources for the Azure AI Studio Hub
module aiDependencies 'modules/ai/hub-dependencies.bicep' = {
  name: 'dependencies-${name}-${uniqueSuffix}-deployment'
  scope: resourceGroup
  params: {
    location: location
    aiServicesName: 'ais${uniqueSuffix}'
    openAiModelDeployments: array(aiConfig.?deployments ?? [])
  }
}

//9. Create Azure AI Studio Hub
module aiHub 'modules/ai/ai-hub.bicep' = {
  name: 'ai-${name}-${uniqueSuffix}-deployment'
  scope: resourceGroup
  params: {
    // workspace organization
    aiHubName: 'aih-${name}-${uniqueSuffix}'
    aiHubFriendlyName: 'aih-${name}-${uniqueSuffix}'
    aiHubDescription: aiHubDescription
    location: location
    tags: tags

    // dependent resources
    aiServicesId: aiDependencies.outputs.openAiId
    aiServicesEndpoint: aiDependencies.outputs.openAiEndpoint
    applicationInsightsId: m_aisn.outputs.applicationInsightId
    containerRegistryId: m_acr.outputs.acrId
    keyVaultId: m_kvn.outputs.keyVaultId
    storageAccountId: m_stg.outputs.stgId
  }
}

//15. Create Azure Machine Learning Workspace
//https://learn.microsoft.com/en-us/azure/templates/microsoft.machinelearningservices/workspaces?pivots=deployment-language-bicep
module m_aml './modules/aml/azureml.bicep' = {
  name: 'deploy_azureml'
  scope: resourceGroup
  params: {
    location: location
    aisnId: m_aisn.outputs.applicationInsightId
    amlcompclustername: !empty(amlcompclustername) ? amlcompclustername : '${abbrs.machineLearningServicesCluster}${environmentName}-${uniqueSuffix}'
    amlcompinstancename: !empty(amlcompinstancename) ? amlcompinstancename : '${abbrs.machineLearningServicesComputeCPU}${environmentName}-${uniqueSuffix}'
    keyvaultId: m_kvn.outputs.keyVaultId
    storageAccountId: m_stg.outputs.stgId
    workspaceName: !empty(workspaceName) ? workspaceName : '${abbrs.machineLearningServicesWorkspaces}${environmentName}-${uniqueSuffix}'
    hbi_workspace: hbi_workspace
    acrId: m_acr.outputs.acrId
    systemDatastoresAuthMode: ((systemDatastoresAuthMode == 'accessKey') ? systemDatastoresAuthMode : 'identity')
    tags: tags
  }
}


//10. Create Create NSG
module m_nsg 'modules/vnet/nsg.bicep' = {
  name: 'deploy_nsg'
  scope: resourceGroup
  params: {
    location: location
    nsgName: !empty(networkSecurityGroupName) ? networkSecurityGroupName : '${abbrs.networkNetworkSecurityGroups}${environmentName}-${uniqueSuffix}'
    securityRules: [
      {
        name: 'In-SSH'
        properties: {
          priority: 1000
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '22'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'open-port-2222'
        properties: {
          priority: 900
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '2222'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'In-Demo-App-GitOps'
        properties: {
          priority: 1001
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '3000'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAnyHTTPSInbound'
        properties: {
          priority: 1011
          sourceAddressPrefix: '*'
          protocol: 'Tcp'
          destinationPortRange: '443'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAnyHTTPInbound'
        properties: {
          priority: 1021
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '80'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAnyCustom5000Inbound'
        properties: {
          priority: 1031
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '5000'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAnyCustom6443Inbound'
        properties: {
          priority: 1041
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '6443'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowAnyCustom8086Inbound'
        properties: {
          priority: 1051
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '8086'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

//11. Create VNET
module m_vnet 'modules/vnet/vnet.bicep' = {
  name: 'deploy_vnet'
  scope: resourceGroup
  params: {
    location: location
    vnetName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${environmentName}-${uniqueSuffix}'
    vnetAddressSpace: vNetAddressSpace
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetCIDR
        }
      }
    ]
  }
}

//12. Create VM/K3s Public IP
module m_pip 'modules/vnet/publicip.bicep' = {
  name: 'deploy_pip'
  scope: resourceGroup
  params: {
    location: location
    publicipName: !empty(publicIPAddressName) ? publicIPAddressName : '${abbrs.networkPublicIPAddresses}${environmentName}-${uniqueSuffix}'
    publicipproperties: {
      publicIPAllocationMethod: 'Static'
      publicIPAddressVersion: 'IPv4'
      idleTimeoutInMinutes: 4
      dnsSettings: {
        domainNameLabel: 'aiobx${uniqueSuffix}'
      }
    }
  }
}

//13. Build reference of existing subnets
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  scope: resourceGroup
  name: '${m_vnet.outputs.vnetName}/${subnetName}'
}

module roleOwner 'modules/identity/role.bicep' = {
  name: 'deployVMRole_Owner'
  scope: resourceGroup
  params:{
    principalId: m_msi.outputs.msiPrincipalID
    roleGuid: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // Owner
  }
  dependsOn: [
    m_msi
    m_stg
  ]
}

//4. Create Required Storage Account with HNS Enabled for AIO Schema
//https://docs.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts
module m_stghns 'modules/storage/storage.bicep' = {
  name: 'deploy_storageaccounthns'
  scope: resourceGroup
  params: {
    storageAccountName: !empty(storageAccountName) ? '${storageAccountName}hns' : '${abbrs.storageStorageAccounts}${environmentName}${uniqueSuffix}hns'
    vmUserAssignedIdentityID: m_msi.outputs.msiPrincipalID
    isHnsEnabled: true
  }
  dependsOn: [
    m_msi
    roleOwner
  ]
}

//14. Create Ubuntu VM for K3s
module m_vm 'modules/vm/vm-ubuntu.bicep' = {
  name: 'deploy_K3sVM'
  scope: resourceGroup
  params: {
    location: location
    virtualMachineSize: virtualMachineSize
    virtualMachineName: !empty(virtualMachineName) ? virtualMachineName : '${abbrs.computeVirtualMachines}${environmentName}-${uniqueSuffix}'
    arcK8sClusterName: arcK8sClusterName
    adminUsername: adminUsername
    adminPasswordOrKey: adminPasswordOrKey
    authenticationType: authenticationType
    vmUserAssignedIdentityID: m_msi.outputs.msiID 
    vmUserAssignedIdentityPrincipalID: m_msi.outputs.msiPrincipalID

    subnetId: subnet.id
    publicIPId: m_pip.outputs.publicipId
    nsgId: m_nsg.outputs.nsgID
    keyVaultId: m_kvn.outputs.keyVaultId
    keyVaultName: m_kvn.outputs.keyVaultName

    scriptURI: scriptURI
    ShellScriptName: ShellScriptName

    customLocationRPSPID: customLocationRPSPID

    spAppId: spAppId
    spSecret: spSecret
    spObjectId: spObjectId
    spAppObjectId: spAppObjectId
    aiServicesEndpoint: aiDependencies.outputs.openAiEndpoints
    aiServicesName: aiDependencies.outputs.openAiName
    stgId: m_stghns.outputs.stgId
  }
  dependsOn: [
    m_nsg
    m_vnet
    m_pip
    m_kvn
    m_stghns
  ]
}

//********************************************************
//Deployment Scripts
//********************************************************
//Attach a Kubernetes cluster to Azure Machine Learning workspace
module script_attachK3sCluster './modules/aml/attachK3sCluster.bicep' = {
  name: 'script_attachK3sCluster'
  scope: resourceGroup
  params: {
    location: location
    resourceGroupName: resourceGroup.name
    amlworkspaceName: m_aml.outputs.amlworkspaceName
    arcK8sClusterName: arcK8sClusterName
    vmUserAssignedIdentityID: m_msi.outputs.msiID
    vmUserAssignedIdentityPrincipalID: m_msi.outputs.msiPrincipalID
  }
  dependsOn:[
    m_vm
    m_aml
  ]
}

//Upload Notebooks to Azure ML Studio
module script_UploadNotebooks './modules/aml/scriptNotebookUpload.bicep' = {
  name: 'script_UploadNotebooks'
  scope: resourceGroup
  params: {
    location: location
    resourceGroupName: resourceGroup.name
    amlworkspaceName: m_aml.outputs.amlworkspaceName
    storageAccountName: m_stg.outputs.stgName

    vmUserAssignedIdentityID: m_msi.outputs.msiID 
    vmUserAssignedIdentityPrincipalID: m_msi.outputs.msiPrincipalID 
  }
  dependsOn:[
    m_msi
    m_aml
  ]
}
