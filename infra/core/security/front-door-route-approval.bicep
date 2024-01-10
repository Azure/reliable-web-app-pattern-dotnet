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

// 1893972 covers moving from implicit to explicit endpoint approvals
@description('A collection of web apps that will be approved for front door private endpoint connection')
param webAppIds string[]

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
    scriptContent: 'rg_name="$ResourceGroupName"; webapp_ids=$(az webapp list -g $rg_name --query "[].id" -o tsv); for webapp_id in $webapp_ids; do fd_conn_ids=$(az network private-endpoint-connection list --id $webapp_id --query "[?properties.provisioningState == \'Pending\'].id" -o tsv); for fd_conn_id in $fd_conn_ids; do az network private-endpoint-connection approve --id "$fd_conn_id" --description "ApprovedByCli"; done; done'         
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'PT1H'
  }
}
