targetScope = 'resourceGroup'

/*
** Find existing secrets and grant access to the reader identities.
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
*/

// ========================================================================
// PARAMETERS
// ========================================================================

@description('Name of the existing Key Vault that contains the secret')
param keyVaultName string

@description('List of user assigned managed identities that will receive Secrets User role to the shared key vault')
param readerIdentities object[]

@description('Name of the existing Key Vault secret that will be readable')
param secretName string

// ========================================================================
// VARIABLES
// ========================================================================

@description('Built in \'Key Vault Secrets User\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var vaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

// ========================================================================
// EXISTING RESOURCES
// ========================================================================

resource existingKeyVault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyVaultName
}

resource existingSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' existing = {
  name: secretName
  parent: existingKeyVault
}

// ========================================================================
// AZURE MODULES
// ========================================================================

resource grantSecretsUserAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in readerIdentities: if (!empty(id.principalId)) {
  name: guid(vaultSecretsUserRoleId, id.principalId, existingSecret.id, resourceGroup().name)
  scope: existingSecret
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', vaultSecretsUserRoleId)
    principalId: id.principalId
  }
}]
