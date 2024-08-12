targetScope = 'resourceGroup'

/*
** Key Vault
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates a Key Vault resource, including permission grants and diagnostics.
*/

import { PrivateEndpointSettings } from '../../types/PrivateEndpointSettings.bicep'
import { DiagnosticSettings } from '../../types/DiagnosticSettings.bicep'
import { ApplicationIdentity } from '../../types/ApplicationIdentity.bicep'

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

type FirewallRules = {
  @description('The list of IP address CIDR blocks to allow access from.')
  allowedIpAddresses: string[]
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The Azure region for the resource.')
param location string

@description('The name of the primary resource')
param name string

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Dependencies
*/
@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/
@description('Whether or not public endpoint access is allowed for this server')
param enablePublicNetworkAccess bool = true

@description('The firewall rules to install on the Key Vault.')
param firewallRules FirewallRules?

@description('The list of application identities to be granted owner access to the application resources.')
param ownerIdentities ApplicationIdentity[] = []

@description('If set, the private endpoint settings for this resource')
param privateEndpointSettings PrivateEndpointSettings?

@description('The list of application identities to be granted reader access to the application resources.')
param readerIdentities ApplicationIdentity[] = []

// ========================================================================
// VARIABLES
// ========================================================================

@description('Built in \'Key Vault Administrator\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var vaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'

@description('Built in \'Key Vault Secrets User\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var vaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

var networkAcls = firewallRules != null ? {
  bypass: 'AzureServices'
  defaultAction: 'Deny'
  ipRules: map(firewallRules!.allowedIpAddresses, (ipAddr) => { value: ipAddr })
} : {
  bypass: 'None'
}

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    enableRbacAuthorization: true
    networkAcls: networkAcls
    publicNetworkAccess: enablePublicNetworkAccess || firewallRules != null ? 'Enabled' : 'Disabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
  }
}

resource grantVaultAdminAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in ownerIdentities: if (!empty(id.principalId)) {
  name: guid(vaultAdministratorRoleId, id.principalId, keyVault.id, resourceGroup().name)
  scope: keyVault
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', vaultAdministratorRoleId)
    principalId: id.principalId
  }
}]

resource grantSecretsUserAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in readerIdentities: if (!empty(id.principalId)) {
  name: guid(vaultSecretsUserRoleId, id.principalId, keyVault.id, resourceGroup().name)
  scope: keyVault
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', vaultSecretsUserRoleId)
    principalId: id.principalId
  }
}]

module privateEndpoint '../network/private-endpoint.bicep' = if (privateEndpointSettings != null) {
  name: '${name}-private-endpoint'
  scope: resourceGroup(privateEndpointSettings != null ? privateEndpointSettings!.resourceGroupName : resourceGroup().name)
  params: {
    name: privateEndpointSettings != null ? privateEndpointSettings!.name : 'pep-${name}'
    location: location
    tags: tags
    dnsRsourceGroupName: privateEndpointSettings == null ? resourceGroup().name : privateEndpointSettings!.dnsResourceGroupName

    // Dependencies
    linkServiceId: keyVault.id
    linkServiceName: keyVault.name
    subnetId: privateEndpointSettings != null ? privateEndpointSettings!.subnetId : ''

    // Settings
    dnsZoneName: 'privatelink.vaultcore.azure.net'
    groupIds: [ 'vault' ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: map([ 'AuditEvent', 'AzurePolicyEvaluationDetails' ], (category) => {
      category: category
      enabled: diagnosticSettings!.enableLogs
    })
    metrics: [
      {
        category: 'AllMetrics'
        enabled: diagnosticSettings!.enableMetrics
      }
    ]
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = keyVault.id
output name string = keyVault.name
output vaultUri string = keyVault.properties.vaultUri
