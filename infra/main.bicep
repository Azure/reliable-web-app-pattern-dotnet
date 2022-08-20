targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unqiue hash used in all resources.')
param name string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

var primaryResourceToken = toLower(uniqueString(subscription().id, name, location))

var tags = {
  'azd-env-name': name
}

var proposedResourceGroupName = '${name}-rg'

// assumes that this will be a multisite deployment when the environment name starts with an azure region
var secondaryLocation = substring(proposedResourceGroupName, 0, indexOf(proposedResourceGroupName,'-'))

// TODO - secondary azure region should be a parameter
var azureRegions = ['eastus','eastus2','westus3','southcentralus']

var isMultiSiteDeployment = contains(azureRegions, secondaryLocation)
var secondaryResourceToken = toLower(uniqueString(subscription().id, name, '2', secondaryLocation))

var resourceGroupNameWithoutRegion = isMultiSiteDeployment ? substring(proposedResourceGroupName, length(secondaryLocation)+1) : 'none'
var primaryResourceGroupName = isMultiSiteDeployment ? 'primary-${resourceGroupNameWithoutRegion}' : proposedResourceGroupName
var secondaryResourceGroupName = 'secondary-${resourceGroupNameWithoutRegion}'

resource primaryResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: primaryResourceGroupName
  location: location
  tags: tags
}

resource secondaryResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = if (isMultiSiteDeployment) {
  name: secondaryResourceGroupName
  location: location
  tags: tags
}

module primaryResources './resources.bicep' = {
  name: 'primary-${primaryResourceToken}'
  scope: primaryResourceGroup
  params: {
    location: location
    environmentName: name
    principalId: principalId
    resourceToken: secondaryResourceToken
    tags: tags
  }
}

module secondaryResources './resources.bicep' = if (isMultiSiteDeployment) {
  name: 'secondary-${primaryResourceToken}'
  scope: isMultiSiteDeployment ? primaryResourceGroup : secondaryResourceGroup
  params: {
    location: secondaryLocation
    environmentName: name
    principalId: principalId
    resourceToken: secondaryResourceToken
    tags: tags
  }
}

module azureFrontDoor './azureFrontDoor.bicep' = if (isMultiSiteDeployment) {
  name: 'frontDoor-${primaryResourceToken}'
  scope: primaryResourceGroup
  params: {
    resourceToken: primaryResourceToken
    tags: tags
    primaryBackendAddress: primaryResources.outputs.WEB_URI
    secondaryBackendAddress: isMultiSiteDeployment ? secondaryResources.outputs.WEB_URI : 'none'
  }
}

output IS_MULTI_SITE bool = isMultiSiteDeployment
output WEB_BASE_URL string = isMultiSiteDeployment ? azureFrontDoor.outputs.WEB_URI : 'none'
output AZURE_LOCATION string = location
