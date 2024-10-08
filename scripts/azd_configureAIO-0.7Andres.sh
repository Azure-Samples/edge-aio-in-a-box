#!/bin/bash

#############################
# Script Params
#############################
# $1 = Azure Resource Group Name
# $2 = Azure Arc for Kubernetes cluster name
# $3 = Azure Arc for Kubernetes cluster location
# $4 = Azure VM User Name
# $5 = Azure VM UserAssignedIdentity PrincipalId
# $6 = Object ID of the Service Principal for Custom Locations RP
# $7 = Azure KeyVault ID
# $8 = Azure KeyVault Name
# $9 = Subscription ID
# $10 = Azure Service Principal App ID
# $11 = Azure Service Principal Secret
# $12 = Azure Service Principal Tenant ID
# $13 = Azure Service Principal Object ID
# $14 = Azure Service Principal App Object ID
# $15 = Azure AI Service Endpoint
# $16 = Azure AI Service Key
# $17 = Azure Storage Resource ID

#  1   ${resourceGroup().name}
#  2   ${arcK8sClusterName}
#  3   ${location}
#  4   ${adminUsername}
#  5   ${vmUserAssignedIdentityPrincipalID}
#  6   ${customLocationRPSPID}
#  7   ${keyVaultId}
#  8   ${keyVaultName}
#  9   ${subscription().subscriptionId}
#  10  ${spAppId}
#  11  ${spSecret}
#  12  ${subscription().tenantId}'
#  13  ${spObjectId}
#  14  ${spAppObjectId}
#  15  ${aiServicesEndpoint}
#  16  ${aiservicesKey}
#  17  ${stgId}

sudo apt-get update

rg=$1
arcK8sClusterName=$2
location=$3
adminUsername=$4
vmUserAssignedIdentityPrincipalID=$5
customLocationRPSPID=$6
keyVaultId=$7
keyVaultName=$8
subscriptionId=$9
spAppId=${10}
spSecret=${11}
tenantId=${12}
spObjectId=${13}
spAppObjectId=${14}
aiServicesEndpoint=${15}
aiservicesKey=${16}
stgId=${17}

#############################
# Script Definition
#############################

echo "";
echo "Paramaters:";
echo "   Resource Group Name: $rg";
echo "   Location: $amlworkspaceName"
echo "   vmUserAssignedIdentityPrincipalID: $vmUserAssignedIdentityPrincipalID"
echo "   customLocationRPSPID: $customLocationRPSPID"
echo "   keyVaultId: $keyVaultId"
echo "   keyVaultName: $keyVaultName"
echo "   subscriptionId: $subscriptionId"
echo "   spAppId: $spAppId"
echo "   spSecret: $spSecret"
echo "   tenantId: $tenantId"
echo "   spObjectId: $spObjectId"
echo "   spAppObjectId: $spAppObjectId"
echo "   aiServicesEndpoint: $aiServicesEndpoint"
echo "   aiservicesKey: $aiservicesKey"
echo "   stgId: $stgId"

# Injecting environment variables
logpath=/var/log/deploymentscriptlog

#############################
# Install Rancher K3s Cluster Jumpstart Method
# Installing Rancher K3s cluster (single control plane)
#############################
echo "Installing Rancher K3s cluster"
publicIp=$(hostname -i)

#############################
# Install Rancher K3s Cluster AI-In-A-Box Method
#############################
echo "Installing Rancher K3s cluster"
#curl -sfL https://get.k3s.io | sh -
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik --node-external-ip ${publicIp}" sh -

mkdir -p /home/$adminUsername/.kube
echo "
export KUBECONFIG=~/.kube/config
source <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k
" >> /home/$adminUsername/.bashrc

USERKUBECONFIG=/home/$adminUsername/.kube/config
sudo k3s kubectl config view --raw > "$USERKUBECONFIG"
chmod 600 "$USERKUBECONFIG"
chown $adminUsername:$adminUsername "$USERKUBECONFIG"

# Set KUBECONFIG for root - Current session
KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

#############################
#Install Helm 
#############################
echo "Installing Helm"
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update -y
sudo apt-get install helm -y
echo "source <(helm completion bash)" >> /home/$adminUsername/.bashrc

#############################
#Install Azure CLI
#############################
echo "Installing Azure CLI"
#curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
# Install a specific version
apt-cache policy azure-cli; sudo apt-get install azure-cli=2.64.0-1~jammy

#############################
#Azure Arc - Onboard the Cluster to Azure Arc
#############################
echo "Connecting K3s cluster to Arc for K8s"
az login --identity --username $vmUserAssignedIdentityPrincipalID
#az login --service-principal -u ${10} -p ${11} --tenant ${12}
#az account set -s $subscriptionId

az config set extension.use_dynamic_install=yes_without_prompt

az extension add --name connectedk8s --yes

# Use the az connectedk8s connect command to Arc-enable your Kubernetes cluster and manage it as part of your Azure resource group
az connectedk8s connect \
    --resource-group $rg \
    --name $arcK8sClusterName \
    --location $location \
    --kube-config /etc/rancher/k3s/k3s.yaml

#############################
#Arc for Kubernetes Extensions
#############################
echo "Configuring Arc for Kubernetes Extensions"
az extension add -n k8s-configuration --yes
az extension add -n k8s-extension --yes

sudo apt-get update -y
sudo apt-get upgrade -y

# Sleep for 60 seconds to allow the cluster to be fully connected
sleep 60

#############################
#Azure IoT Operations
#############################
# Starting off the post deployment steps. The following steps are to deploy Azure IoT Operations components
# Reference: https://learn.microsoft.com/en-us/azure/iot-operations/deploy-iot-ops/howto-prepare-cluster?tabs=ubuntu#create-a-cluster
# Reference: https://learn.microsoft.com/en-us/cli/azure/iot/ops?view=azure-cli-latest#az-iot-ops-init
echo "Deploy IoT Operations Components. These commands take several minutes to complete."

#Increase user watch/instance limits:
echo fs.inotify.max_user_instances=8192 | sudo tee -a /etc/sysctl.conf
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
#Increase file descriptor limit:
echo fs.file-max = 100000 | sudo tee -a /etc/sysctl.conf 

sudo sysctl -p

#Use the az connectedk8s enable-features command to enable custom location support on your cluster.
#This command uses the objectId of the Microsoft Entra ID application that the Azure Arc service uses.
echo "Enabling custom location support on the Arc cluster"

az connectedk8s enable-features -g $rg \
    -n $arcK8sClusterName \
    --custom-locations-oid $customLocationRPSPID \
    --features cluster-connect custom-locations

# Initial values for variables
SCHEMA_REGISTRY="aiobxregistry"
SCHEMA_REGISTRY_NAMESPACE="aiobxregistryns"

# Generate random 3-character suffix (alphanumeric)
SUFFIX=$(tr -dc 'a-z0-9' </dev/urandom | head -c 4)

# Append the unique suffixes to the variables
SCHEMA_REGISTRY="${SCHEMA_REGISTRY}${SUFFIX}"
SCHEMA_REGISTRY_NAMESPACE="${SCHEMA_REGISTRY_NAMESPACE}${SUFFIX}"

az extension add -name azure-iot-ops --upgrade --yes --allow-preview false

echo "Create a schema registry which will be used by Azure IoT Operations components after the deployment and connects it to the Azure Storage account."
# az iot ops schema registry create -g $rg -n $SCHEMA_REGISTRY --registry-namespace $SCHEMA_REGISTRY_NAMESPACE --sa-resource-id $(az storage account show --name $STORAGE_ACCOUNT -o tsv --query id) --sa-container schemas
az iot ops schema registry create -g $rg -n $SCHEMA_REGISTRY --registry-namespace $SCHEMA_REGISTRY_NAMESPACE --sa-resource-id "${stgId}" --sa-container schemas

echo "Prepare the cluster for Azure IoT Operations deployment."
#az iot ops schema registry show --name aiobxregistry1 --resource-group aiobxap070-aioedgeai-rg -o tsv --query id
#az iot ops init -g aiobxap070-aioedgeai-rg --cluster aiobmclusterap --sr-resource-id "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx/resourceGroups/aiobxap070-aioedgeai-rg/providers/Microsoft.DeviceRegistry/schemaRegistries/aiobxregistry1"
az iot ops init -g $rg \
    --cluster $arcK8sClusterName \
    --sr-resource-id "$(az iot ops schema registry show --name $SCHEMA_REGISTRY --resource-group $rg -o tsv --query id)"

echo "Deploy Azure IoT Operations."
az iot ops create -g $rg \
    --cluster $arcK8sClusterName \
    --custom-location "${arcK8sClusterName}-cl-${SUFFIX}" \
    -n "${arcK8sClusterName}-ops-instance"


#############################
#Arc for Kubernetes AML Extension
#############################
#https://learn.microsoft.com/en-us/azure/machine-learning/how-to-deploy-kubernetes-extension
# allowInsecureConnections=True - Allow HTTP communication or not. HTTP communication is not a secure way. If not allowed, HTTPs will be used.
# InferenceRouterHA=False       - By default, AzureML extension will deploy 3 ingress controller replicas for high availability, which requires at least 3 workers in a cluster. Set this to False if you have less than 3 workers and want to deploy AzureML extension for development and testing only, in this case it will deploy one ingress controller replica only.


#############################
#Deploy Namespace, InfluxDB, Simulator, and Redis
#############################
#Create a folder for Cerebral configuration files
mkdir -p /home/$adminUsername/cerebral
sleep 30

#Apply the Cerebral namespace
kubectl apply -f https://raw.githubusercontent.com/Azure/arc_jumpstart_drops/main/sample_app/cerebral_genai/deployment/cerebral-ns.yaml

#Create a directory for persistent InfluxDB data
sudo mkdir /var/lib/influxdb2
sudo chmod 777 /var/lib/influxdb2

#Deploy InfluxDB, Configure InfluxDB, and Deploy the Data Simulator
