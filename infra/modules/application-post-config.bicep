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

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/DeploymentSettings.bicep
@description('Type that describes the global deployment settings')
type DeploymentSettings = {
  @description('If \'true\', then two regional deployments will be performed.')
  isMultiLocationDeployment: bool
  
  @description('If \'true\', use production SKUs and settings.')
  isProduction: bool

  @description('If \'true\', isolate the workload in a virtual network.')
  isNetworkIsolated: bool

  @description('If \'false\', then this is a multi-location deployment for the second location.')
  isPrimaryLocation: bool

  @description('The Azure region to host resources')
  location: string

  @description('The name of the workload.')
  name: string

  @description('The ID of the principal that is being used to deploy resources.')
  principalId: string

  @description('The name of the principal that is being used to deploy resources.')
  principalName: string

  @description('The type of the \'principalId\' property.')
  principalType: 'ServicePrincipal' | 'User'

  @description('The token to use for naming resources.  This should be unique to the deployment.')
  resourceToken: string

  @description('The development stage for this application')
  stage: 'dev' | 'prod'

  @description('The common tags that should be used for all created resources')
  tags: object

  @description('The common tags that should be used for all workload resources')
  workloadTags: object
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

/*
** Passwords - specify these!
*/
@secure()
@minLength(12)
@description('The password for the administrator account.  This will be used for the jump box and anywhere else a password is needed for creating a resource.')
param administratorPassword string = newGuid()

@minLength(8)
@description('The username for the administrator account on the jump box.')
param administratorUsername string = 'adminuser'

@description('The resource names for the resources to be created.')
param resourceNames object

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

module writeJumpBoxCredentialsToKeyVault '../core/security/key-vault-secrets.bicep' = if (deploymentSettings.isNetworkIsolated) {
  name: 'hub-write-jumpbox-credentials-${deploymentSettings.resourceToken}'
  scope: existingKvResourceGroup
  params: {
    name: existingKeyVault.name
    secrets: [
      { key: 'Jumpbox--AdministratorPassword', value: administratorPassword          }
      { key: 'Jumpbox--AdministratorUsername', value: administratorUsername          }
      { key: 'Jumpbox--ComputerName',          value: resourceNames.hubJumpbox }
    ]
  }
}

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
