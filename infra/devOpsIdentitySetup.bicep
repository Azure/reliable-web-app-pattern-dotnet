
@minLength(1)
@description('Primary location for all resources. Should specify an Azure region. e.g. `eastus2` ')
param location string

@minLength(1)
@description('A generated identifier used to create unique resources')
param resourceToken string

@description('An object collection that contains annotations that describe the deployed azure resources to improve operational visibility')
param tags object

@description('A user-assigned managed identity that is used to run deploymentScripts on this resource group.')
resource devOpsManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'devops-${resourceToken}-identity'
  location: location
  tags: tags
}

@description('Built in \'Contributor\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
// Allows read access to App Configuration data
var contributorRole = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource devOpsIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(contributorRole, devOpsManagedIdentity.id)
  scope: resourceGroup()
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', contributorRole)
    principalId: devOpsManagedIdentity.properties.principalId
    description: 'Grant the "Contributor" role to the user-assigned managed identity so it can run deployment scripts.'
  }
}

output devOpsManagedIdentityId string = devOpsManagedIdentity.id
