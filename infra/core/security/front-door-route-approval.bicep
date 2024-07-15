/*
** Azure Front Door Route Approval
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The Azure region used to host the deployment script')
param location string

@description('The owner managed identity used to auto-approve the private endpoint')
param managedIdentityName string

@description('Force the deployment script to run')
param utcValue string = utcNow()

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource approval 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'auto-approve-private-endpoint'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.47.0'
    timeout: 'PT30M'
    environmentVariables: [
      {
        name: 'ResourceGroupName'
        value: resourceGroup().name
      }
    ]
    scriptContent: loadTextContent('./scripts/front-door-route-approval.sh')
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
  }
}
