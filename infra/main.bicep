targetScope = 'subscription'

@minLength(1)
@description('Name of the azd environment.')
param environmentName string

@description('Azure region used for all resources.')
param location string

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = {
  'azd-env-name': environmentName
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-logicapps-${environmentName}-${resourceToken}'
  location: location
  tags: tags
}

module application './resources.bicep' = {
  name: 'logicappsstandard-${resourceToken}'
  scope: resourceGroup
  params: {
    location: location
    resourceToken: resourceToken
    tags: tags
  }
}

output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = resourceGroup.name
output SERVICE_WORKFLOWS_NAME string = application.outputs.logicAppName
output SERVICE_WORKFLOWS_URI string = application.outputs.logicAppUri
