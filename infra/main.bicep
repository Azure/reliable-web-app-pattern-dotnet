targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unqiue hash used in all resources.')
param name string

@minLength(1)
@description('Primary location for all resources. Should specify an Azure region. e.g. `eastus2` ')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Will select production ready SKUs when `true`')
param isProd string = 'false'

@description('Should specify an Azure region, if not set to none, to trigger multiregional deployment. The second region should be different than the `location` . e.g. `westus3`')
param secondaryAzureLocation string

var isProdBool = isProd == 'true' ? true : false

var tags = {
  'azd-env-name': name
}

var isMultiLocationDeployment = secondaryAzureLocation == '' ? false : true

//var primaryResourceGroupName = isMultiLocationDeployment ? 'primary-${name}-rg' : '${name}-rg'
var primaryResourceGroupName = '${name}-rg'
var secondaryResourceGroupName = 'secondary-${name}-rg'

var primaryResourceToken = toLower(uniqueString(subscription().id, primaryResourceGroupName, location))
var secondaryResourceToken = toLower(uniqueString(subscription().id, secondaryResourceGroupName, secondaryAzureLocation))

resource primaryResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: primaryResourceGroupName
  location: location
  tags: tags
}

resource secondaryResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = if (isMultiLocationDeployment) {
  name: secondaryResourceGroupName
  location: secondaryAzureLocation
  tags: tags
}

module primaryResources './resources.bicep' = {
  name: 'primary-${primaryResourceToken}'
  scope: primaryResourceGroup
  params: {
    isProd: isProdBool
    location: location
    environmentName: name
    principalId: principalId
    resourceToken: primaryResourceToken
    tags: tags
  }
}

module secondaryResources './resources.bicep' = if (isMultiLocationDeployment) {
  name: 'secondary-${primaryResourceToken}'
  // scope: isMultiLocationDeployment ? secondaryResourceGroup : primaryResourceGroup
  scope: secondaryResourceGroup
  params: {
    isProd: isProdBool
    location: secondaryAzureLocation
    environmentName: name
    principalId: principalId
    resourceToken: secondaryResourceToken
    tags: tags
  }
}

module azureFrontDoor './azureFrontDoor.bicep' = if (isMultiLocationDeployment) {
  name: 'frontDoor-${primaryResourceToken}'
  scope: primaryResourceGroup
  params: {
    resourceToken: primaryResourceToken
    tags: tags
    primaryBackendAddress: primaryResources.outputs.WEB_URI
    secondaryBackendAddress: isMultiLocationDeployment ? secondaryResources.outputs.WEB_URI : 'none'
  }
}

output WEB_URI string = isMultiLocationDeployment ? azureFrontDoor.outputs.WEB_URI : primaryResources.outputs.WEB_URI
output AZURE_LOCATION string = location

output DEBUG_IS_MULTI_LOCATION_DEPLOYMENT bool = isMultiLocationDeployment
output DEBUG_SECONDARY_AZURE_LOCATION string = secondaryAzureLocation
output DEBUG_IS_PROD bool = isProdBool
