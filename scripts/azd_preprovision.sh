 #!/bin/sh

########################################################################
# Connect to Azure
########################################################################
echo "Connecting to Azure..."
echo "Setting Azure context with subscription id $AZURE_SUBSCRIPTION_ID ..."
az account set --subscription $AZURE_SUBSCRIPTION_ID

########################################################################
# Registering resource providers
########################################################################
# Register providers
echo "Registering Azure providers..."

# Check if the SKIP_AZURE_PROVIDER_REGISTRATION environment variable is set
# If it is set, skip the provider registration to make inner loop development faster
if [ -z "$SKIP_AZURE_PROVIDER_REGISTRATION" ]; then
###################
# List of required azure providers
###################
  azProviders="
      Microsoft.AlertsManagement \
      Microsoft.Compute \
      Microsoft.ContainerInstance \
      Microsoft.ContainerService \
      Microsoft.DeviceRegistry \
      Microsoft.EventHub \
      Microsoft.ExtendedLocation \
      Microsoft.IoTOperations \
      Microsoft.IoTOperationsDataProcessor \
      Microsoft.IoTOperationsMQ \
      Microsoft.IoTOperationsOrchestrator \
      Microsoft.KeyVault \
      Microsoft.Kubernetes \
      Microsoft.KubernetesConfiguration \
      Microsoft.ManagedIdentity \
      Microsoft.Network \
      Microsoft.Relay"

# Start all providers registrations in parallel
  for resourceProvider in ${azProviders}; do
      echo "Start registering provider $resourceProvider..."
      az provider register --namespace $resourceProvider
  done
# Wait for all providers to be registered
  for resourceProvider in ${azProviders}; do
      echo "Wait for $resourceProvider to be registered..."
      az provider register --namespace $resourceProvider --wait
      echo "Provider $resourceProvider is registered."
  done
fi

###################
# Retrieving the custom RP SP ID
# Get the objectId of the Microsoft Entra ID application that the Azure Arc service uses and save it as an environment variable.
###################
echo "Retrieving the Custom Location RP ObjectID from SP ID bc313c14-388c-4e7d-a58e-70017303ee3b"
# Make sure that the command below is and/or pointing to the correct subscription and the MS Tenant
customLocationRPSPID=$(az ad sp show --id bc313c14-388c-4e7d-a58e-70017303ee3b --query id -o tsv)
echo "Custom Location RP SP ID: $customLocationRPSPID"
azd env set AZURE_ENV_CUSTOMLOCATIONRPSPID $customLocationRPSPID

###################
# Create a service principal used by IoT Operations to interact with Key Vault
###################
echo "Creating a service principal for IoT Operations to interact with Key Vault..."
iotOperationsKeyVaultSP=$(az ad sp create-for-rbac --name "aiobx-keyvault-sp" --role "Owner" --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID)
spAppId=$(echo $iotOperationsKeyVaultSP | jq -r '.appId')
spSecret=$(echo $iotOperationsKeyVaultSP | jq -r '.password')
spobjId=$(az ad sp show --id $spAppId --query id -o tsv)
spAppObjId = $(az ad app show --id $spAppId --query id -o tsv)

echo "Setting the service principal environment variables..."
azd env set AZURE_ENV_SPAPPID $spAppId
azd env set AZURE_ENV_SPSECRET $spSecret
azd env set AZURE_ENV_SPOBJECTID $spobjId
azd env set AZURE_ENV_SPAPPOBJECTID $spAppObjId