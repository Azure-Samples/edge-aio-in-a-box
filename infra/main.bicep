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

        To Run:
        az login
        az account set --subscription <subscription id>
        az group create --name <your resource group name> --location <your resource group location>
        az ad user show --id 'your email' --query id

        az bicep build --file main.bicep
        az deployment group create --resource-group <your resource group name>  --template-file main.bicep --parameters main.paraeters.json --name AIO-in-a-Box --query 'properties.outputs'

        SCRIPT STEPS
       1 - Create Resource Group
       2 - Create User Assigned Identity for VM
       3 - Create NSG
       4 - Create VNET
       5 - Create OPNsense Public IP
       6 - Create KeyVault used for Azure IoT Operations
       7 - Build reference of existing subnets
       8 - Create Ubuntu VM for K3s
       9 - Create Required Storage Account(s)
      10 - Create Application Insights
      11 - Create Azure Container Registry
      12 - Create Azure Machine Learning Workspace
      13 - Deploy Application using GitOps
   
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
var keyVaultName = '' //'${virtualMachineName}-kv'

@description('Your Service Principal Object ID or your own User Object ID so you can give the SP access to the Key Vault Secrets')
param spObjectId string = '' //This is your Service Principal Object ID or your own User Object ID so you can give the SP access to the Key Vault Secrets

@description('Service Principal App ID')
param spAppId string = ''

@description('Service Principal Secret')
@secure()
param spSecret string = ''

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
param virtualMachineSize string = 'Standard_B4ms'

@sys.description('Ubuntu K3s Manchine Name')
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
  'sshPublicKey'
  'password'
])
param authenticationType string


@sys.description('URI for Custom K3s VM Script and Config')
//param scriptURI string = 'https://raw.githubusercontent.com/Azure/AI-in-a-Box/AIO-with-AI/edge-ai/AIO-with-AI/scripts/'
param scriptURI string

@sys.description('Shell Script to be executed')
//param ShellScriptName string = 'script.sh'
param ShellScriptName string


// @sys.description('Name of the Application to be deployed using GitOps')
// param gitOpsAppName string

// @sys.description('Name of the namespace in K3s for the Application to be deployed using GitOps')
// param gitOpsAppNamespace string

// @sys.description('Git Repository URL for the Application to be deployed using GitOps')
// param gitOpsGitRepositoryUrl string

// @sys.description('Git Repository Branch for the Application to be deployed using GitOps')
// param gitOpsGitRepositoryBranch string

// @sys.description('Git Repository Path for the Application to be deployed using GitOps')
// param gitOpsAppPath string

@sys.description('Custom Locations RP ObjectID')
param customLocationRPSPID string = ''


//Storage Account
var storageAccountName = ''

//Application Insights
var applicationInsightsName = ''

//ACR Module Parameters
param acrName string = ''
@description('The SKU to use for the Azure Container Registry.')
param acrSku string = 'Standard'

//Azure ML
var workspaceName = ''
@description('Specifies the name of the Azure Machine Learning workspace Compute Name.')
param amlcompclustername string = ''
@description('Specifies the name of the Azure Machine Learning workspace Compute Name.')
param amlcompinstancename string = ''
@description('Specifies whether to reduce telemetry collection and enable additional encryption.')
param hbi_workspace bool = false
@description('Identity type of storage account services for your azure ml workspace.')
param systemDatastoresAuthMode string = 'identity'

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

//2. Deploy UAMI
module m_msi 'modules/identity/msi.bicep' = {
  name: 'deploy_msi'
  scope: resourceGroup
  params: {
    location: location
    msiName: !empty(msiName) ? msiName : '${abbrs.managedIdentityUserAssignedIdentities}${environmentName}-${uniqueSuffix}'
    tags: tags
  }
}

//3. Deploy Create NSG
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
    ]
  }
}

//4. Create VNET
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

//5. Create OPNsense Public IP
module m_pip 'modules/vnet/publicip.bicep' = {
  name: 'deploy_pip'
  scope: resourceGroup
  params: {
    location: location
    publicipName: !empty(publicIPAddressName) ? publicIPAddressName : '${abbrs.networkPublicIPAddresses}${environmentName}-${uniqueSuffix}'
    publicipproperties: {
      publicIPAllocationMethod: 'Static'
    }
  }
}

//6. Create KeyVault used for Azure IoT Operations
//https://docs.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults
module m_kvn 'modules/keyvault/keyvault.bicep' = {
  name: 'deploy_keyvault'
  scope: resourceGroup
  params: {
    location: location
    keyVaultName: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${environmentName}-${uniqueSuffix}'
    vmUserAssignedIdentityPrincipalID: m_msi.outputs.msiPrincipalID

    //Send in Service Principal and/or User Oject ID
    spObjectId: spObjectId
  }
}

//7. Build reference of existing subnets
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  scope: resourceGroup
  name: '${m_vnet.outputs.vnetName}/${subnetName}'
}

//8. Create Ubuntu VM for K3s
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
    vmUserAssignedIdentityID: m_msi.outputs.msiID //make sure this is the correct one because it could be msiclientid
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

  }
  dependsOn: [
    m_nsg
    m_vnet
    m_pip
    m_kvn
  ]
}

//9. Create Required Storage Account(s)
//Deploy Storage Accounts (Create your Storage Account (ADLS Gen2 & HNS Enabled) for your ML Workspace)
//https://docs.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts?tabs=bicep
module m_stg 'modules/aml/storage.bicep' = {
  name: 'deploy_storageaccount'
  scope: resourceGroup
  params: {
    storageAccountName: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${environmentName}${uniqueSuffix}'
    location: location
  }
}

//6. Deploy Application Insights Instance
//https://learn.microsoft.com/en-us/azure/templates/microsoft.insights/components?pivots=deployment-language-bicep
module m_aisn 'modules/aml/insights.bicep' = {
  name: 'deploy_appinsights'
  scope: resourceGroup
  params: {
    location: location
    applicationInsightsName:  !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${environmentName}-${uniqueSuffix}'
  }
}


//10. Create Azure Container Registry
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

//10. Create Azure Machine Learning Workspace
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
    systemDatastoresAuthMode: ((systemDatastoresAuthMode != 'accessKey') ? systemDatastoresAuthMode : 'identity')
    tags: tags
  }
}

// module gitOpsAppDeploy 'modules/gitops/gtiops.bicep' = {
//   name: 'gitOpsAppDeploy'
//   scope: resourceGroup
//   params: {
//     arcK8sClusterName: arcK8sClusterName
//     gitOpsAppName: gitOpsAppName
//     gitOpsAppNamespace: gitOpsAppNamespace
//     gitOpsGitRepositoryUrl: gitOpsGitRepositoryUrl
//     gitOpsGitRepositoryBranch: gitOpsGitRepositoryBranch
//     gitOpsAppPath: gitOpsAppPath
//   }
//   dependsOn: [
//     m_vm
//   ]
// }
