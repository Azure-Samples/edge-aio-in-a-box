/*region Header
      Module Steps 
      1 - Creates Azure dependent resources for Azure AI studio
*/

//Declare Parameters--------------------------------------------------------------------------------------------------------------------------
@description('Azure region of the deployment')
param location string = resourceGroup().location

@description('AI services name')
param aiServicesName string

@description('Array of OpenAI model deployments')
param openAiModelDeployments array = []

module cognitiveServices '../ai/cognitiveservices.bicep' = {
  name: 'cognitiveServices'
  params: {
    location: location
    name: aiServicesName
    kind: 'OpenAI'
    deployments: openAiModelDeployments
  }
}

output openAiId string = cognitiveServices.outputs.id
output openAiName string = cognitiveServices.outputs.name
output openAiEndpoint string = cognitiveServices.outputs.endpoints['OpenAI Language Model Instance API']
