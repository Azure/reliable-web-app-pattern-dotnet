targetScope = 'subscription'

@description('Indicates whether the environment is production or not')
param isProd bool = false

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param webServiceName string = 'cost-optimization-web'

@description('Id of the user or app to assign application roles')
param principalId string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${environmentName}-cost-${abbrs.resourcesResourceGroups}'
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  name: 'primary-${resourceToken}'
  scope: rg
  params: {
    isProd: isProd
    location: location
    resourceToken: resourceToken
    environmentName: environmentName
    tags: tags
    webServiceName: webServiceName
  }
}


// App outputs
output AZURE_LOCATION string = location
output WEB_URL string = resources.outputs.WEB_APP_URL
