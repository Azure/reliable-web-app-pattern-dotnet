targetScope = 'subscription'

/*
** Application Infrastructure post-configuration
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** The Application consists of a virtual network that has shared resources that
** are generally associated with a hub. This module provides post-configuration
** actions such as creating key-vault secrets to save information from
** modules that depend on the hub.
*/

import { DeploymentSettings } from '../types/DeploymentSettings.bicep'

// ========================================================================
// PARAMETERS
// ========================================================================

/*
** Dependencies
*/
@description('The resource names for the resources to be created.')
param keyVaultName string

@description('Name of the hub resource group containing the key vault.')
param kvResourceGroupName string

@description('List of user assigned managed identities that will receive Secrets User role to the shared key vault')
param readerIdentities object[]

// ========================================================================
// VARIABLES
// ========================================================================

var microsoftEntraIdApiClientId = 'Api--MicrosoftEntraId--ClientId'
var microsoftEntraIdApiInstance = 'Api--MicrosoftEntraId--Instance'
var microsoftEntraIdApiScope = 'App--RelecloudApi--AttendeeScope'
var microsoftEntraIdApiTenantId = 'Api--MicrosoftEntraId--TenantId'
var microsoftEntraIdCallbackPath = 'MicrosoftEntraId--CallbackPath'
var microsoftEntraIdClientId = 'MicrosoftEntraId--ClientId'
var microsoftEntraIdClientSecret = 'MicrosoftEntraId--ClientSecret'
var microsoftEntraIdInstance = 'MicrosoftEntraId--Instance'
var microsoftEntraIdSignedOutCallbackPath = 'MicrosoftEntraId--SignedOutCallbackPath'
var microsoftEntraIdTenantId = 'MicrosoftEntraId--TenantId'

var listOfAppConfigSecrets = [
  microsoftEntraIdApiClientId
  microsoftEntraIdApiInstance
  microsoftEntraIdApiScope
  microsoftEntraIdApiTenantId
  microsoftEntraIdCallbackPath
  microsoftEntraIdClientId
  microsoftEntraIdClientSecret
  microsoftEntraIdInstance
  microsoftEntraIdSignedOutCallbackPath
  microsoftEntraIdTenantId
]

// ========================================================================
// EXISTING RESOURCES
// ========================================================================

resource existingKvResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: kvResourceGroupName
}

resource existingKeyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
  scope: existingKvResourceGroup
}

// ========================================================================
// AZURE MODULES
// ========================================================================

// ======================================================================== //
// Microsoft Entra Application Registration placeholders
// ======================================================================== //
module writeAppRegistrationSecrets '../core/security/key-vault-secrets.bicep' = [ for secretName in listOfAppConfigSecrets: {
  name: 'write-temp-kv-secret-${secretName}'
  scope: existingKvResourceGroup
  params: {
    name: existingKeyVault.name
    secrets: [
      { key: secretName, value: 'placeholder-populated-by-script' }
    ]
  }
}]

// ======================================================================== //
// Grant reader permissions for the web apps to access the key vault
// ======================================================================== //

module grantSecretsUserAccessBySecretName './grant-secret-user.bicep' = [ for secretName in listOfAppConfigSecrets: {
  scope: existingKvResourceGroup
  name: 'grant-kv-access-for-${secretName}'
  params: {
    keyVaultName: existingKeyVault.name
    readerIdentities: readerIdentities
    secretName: secretName
  }
  dependsOn: [
    writeAppRegistrationSecrets
  ]
}]
