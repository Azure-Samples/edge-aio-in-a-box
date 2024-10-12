# Deployment of AIO with Edge AI in-a-Box

## Prerequisites
The following prerequisites are needed for a succesfull deployment of this accelator from your own PC. 

* An [Azure subscription](https://azure.microsoft.com/en-us/free/).
* Install latest version of [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest)
* Install [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd)
* Enable the Following [Resource Providers](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types) on your Subscription:
    - Microsoft.AlertsManagement
    - Microsoft.Compute
    - Microsoft.ContainerInstance
    - Microsoft.ContainerService
    - Microsoft.DeviceRegistry
    - Microsoft.EventHub
    - Microsoft.ExtendedLocation
    - Microsoft.IoTOperations
    - Microsoft.IoTOperationsDataProcessor
    - Microsoft.IoTOperationsMQ
    - Microsoft.IoTOperationsOrchestrator
    - Microsoft.KeyVault
    - Microsoft.Kubernetes
    - Microsoft.KubernetesConfiguration
    - Microsoft.ManagedIdentity
    - Microsoft.Network
    - Microsoft.Relay

    (The template will enable all these Resource Providers but its always good to check pre and post deployment.)

* Install latest version of [Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)

* Be aware that the template will leverage the following [Azure CLI Extensions](https://learn.microsoft.com/en-us/cli/azure/azure-cli-extensions-list): 
    * az extension add -n [azure-iot-ops](https://github.com/azure/azure-iot-ops-cli-extension) --allow-preview true 
    * az extension add -n [connectedk8s](https://github.com/Azure/azure-cli-extensions/tree/main/src/connectedk8s) 
    * az extension add -n [k8s-configuration](https://github.com/Azure/azure-cli-extensions/tree/master/src/k8sconfiguration) 
    * az extension add -n [k8s-extension](https://github.com/Azure/azure-cli-extensions/tree/main/src/k8s-extension) 
    * az extension add -n [ml](https://github.com/Azure/azureml-examples)
    
* Install latest [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) version (7.x): Check your current version with $PSVersionTable and then install the latest via "Winget install microsoft.azd"

* Install [VS Code](https://code.visualstudio.com/docs) on your machine

* **Ownerships rights on the Microsoft Azure subscription**. Ensure that the user or service principal you are using to deploy the accelerator has access to the Graph API in the target tenant. This is necessary because you will need to:
    - Export **OBJECT_ID** = $(az ad sp show --id bc313c14-388c-4e7d-a58e-70017303ee3b --query id -o tsv)
    - Make sure you retrieve this value from a tenant where you have the necessary permissions to access the Graph API. 
    - https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/custom-locations
    - https://learn.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest

    **(Basically you need to deploy the template with a user that has high privelages)**

## Deployment Flow 

**Step 1.** Clone the [Edge-AIO-in-a-Box Repository](https://github.com/Azure-Samples/edge-aio-in-a-box)

**Step 2.** Create Azure Resources (User Assigned Managed Identity, VNET, Key Vault, EventHub, Ubuntu VM, Azure ML Workspace, Container Registry, etc.)

    Sample screenshot of the resources that will be deployed:
![AIO with AI Resources](/readme_assets/aioairesources.png) 

**Step 2.** SSH onto the Ubuntu VM and execute some ***kubectl*** commands to become familiar with the deployed pods and their configurations within the cluster. This hands-on approach will help you understand the operational environment and the resources running in your Kubernetes/AIO setup.

**Step 3.** Buld ML model into docker image and deploy to your K3s Cluster Endpoint via the Azure ML Extension

**Step 4.** Push model to Azure Container Registry

**Step 5.** Deploy model to the Edge via Azure ML Extension to your K3s/AIO Cluster

## Deploy to Azure

1. Clone this repository locally: 

    ```bash
    git clone https://github.com/Azure-Samples/edge-aio-in-a-box
    ```

1. Log into your Azure subscription  (both are required): 
    ```bash
    azd auth login --use-device-code --tenant-id xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx
    ```
    ```bash
    az login --use-device-code --tenant xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx
    ```

1. Deploy resources:
    ```bash
    azd up
    ```

    You will be prompted for a subcription, region and additional parameters:

    ```bash
        adminPasswordOrKey - Pa$$W0rd:)7:)7
        adminUsername - ArcAdmin
        arcK8sClusterName - aioxclusterYOURINITIALS
        authenticationType - password
        location - eastus
        virtualMachineName - aiobxclustervmYOURINITIALS
        virtualMachineSize - Standard_D16s_v4
    ```
## Be Aware
 - export OBJECT_ID = $(az ad sp show --id bc313c14-388c-4e7d-a58e-70017303ee3b --query id -o tsv)
 - You need to make sure that you get this value from a tenant that you have access to get to the graph api in the tenant. 
 - https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/custom-locations
 - https://learn.microsoft.com/en-us/cli/azure/ad/sp?view=azure-cli-latest

 - When you do a redeployment of the whole solution under the same name - it can take till seven days to remove the KeyVault. Use a different environment name for deployment if you need to re-deploy faster.
