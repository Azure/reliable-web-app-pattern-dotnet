targetScope = 'resourceGroup'

/*
** Assigns a role to a managed identity
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/


// ========================================================================
// PARAMETERS
// ========================================================================

@description('The name of a managed identity.')
param identityName string

@description('Azure role id for assignment')
param roleId string

@description('A description of the purpose for the role assignment')
param roleDescription string


// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: identityName
}

resource devOpsIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(roleId, identityName, resourceGroup().id)
  scope: resourceGroup()
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleId)
    principalId: managedIdentity.properties.principalId
    description: roleDescription
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output identity_name string = identityName
