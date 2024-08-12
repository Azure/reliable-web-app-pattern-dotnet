targetScope = 'resourceGroup'

/*
** Write secrets to Key Vault
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Writes a set of secrets to the connected Key Vault.
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

@description('The form of each Key Vault Secret to store.')
@secure()
type KeyVaultSecret = {
  @description('The key for the secret')
  key: string

  @description('The value of the secret')
  value: string
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The name of the Key Vault resource')
param name string

/*
** Settings
*/
@description('The list of secrets to store in the Key Vault')
param secrets KeyVaultSecret[]

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: name
}

resource keyVaultSecretResources 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = [for secret in secrets: {
  name: secret.key
  parent: keyVault
  properties: {
    contentType: 'text/plain; charset=utf-8'
    value: secret.value
  }
}]

#disable-next-line outputs-should-not-contain-secrets // Doesn't contain a secret, just contains the ID references
output secret_ids array = [for (secret, i) in secrets: keyVaultSecretResources[i].id]
