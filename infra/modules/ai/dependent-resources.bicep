/*region Header
      Module Steps 
      1 - Creates Azure dependent resources for Azure AI studio
*/

//Declare Parameters--------------------------------------------------------------------------------------------------------------------------
@description('Azure region of the deployment')
param location string = resourceGroup().location

@description('AI services name')
param aiServicesName string

resource aiServices 'Microsoft.CognitiveServices/accounts@2021-10-01' = {
  name: aiServicesName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices' // or 'OpenAI'
  properties: {
    apiProperties: {
      statisticsEnabled: false
    }
  }
}

output aiservicesID string = aiServices.id
output aiservicesTarget string = aiServices.properties.endpoint
