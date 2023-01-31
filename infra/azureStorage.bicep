@minLength(1)
@description('Primary location for all resources. Should specify an Azure region. e.g. `eastus2` ')
param location string

@minLength(1)
@description('A generated identifier used to create unique resources')
param resourceToken string

@description('An object collection that contains annotations to describe the deployed azure resources to improve operational visibility')
param tags object

@description('Enables the template to choose different SKU by environment')
param isProd bool
param roleAssignmentsList array

var storageSku = isProd ? 'Standard_ZRS' : 'Standard_LRS'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: '${resourceToken}storage' //storage account name cannot contain character '-'
  tags: tags
  location: location
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
}
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  parent: storageAccount
  name:'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  parent: blobServices
  name: 'tickets'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleAssignment in roleAssignmentsList: {
  name: guid(roleAssignment.principalId, roleAssignment.roleDefinitionId, resourceGroup().id)
  scope: container
  properties: {
    description: roleAssignment.description
    principalId: roleAssignment.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAssignment.roleDefinitionId)
    principalType: roleAssignment.principalType
  }
}]

output storageAccountResourceId string = storageAccount.id
output storageAccocuntBlobURL string = storageAccount.properties.primaryEndpoints.blob
output containerId string = container.id
output containerName string = container.name
