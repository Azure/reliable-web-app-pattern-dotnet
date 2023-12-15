targetScope = 'resourceGroup'

/*
** App Configuration Store
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates an Azure App Configuration Store resource, including permission grants and diagnostics.
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/ApplicationIdentity.bicep
@description('Type describing an application identity.')
type ApplicationIdentity = {
  @description('The ID of the identity')
  principalId: string

  @description('The type of identity - either ServicePrincipal or User')
  principalType: 'ServicePrincipal' | 'User'
}

// From: infra/types/DiagnosticSettings.bicep
@description('The diagnostic settings for a resource')
type DiagnosticSettings = {
  @description('The number of days to retain log data.')
  logRetentionInDays: int

  @description('The number of days to retain metric data.')
  metricRetentionInDays: int

  @description('If true, enable diagnostic logging.')
  enableLogs: bool

  @description('If true, enable metrics logging.')
  enableMetrics: bool
}

// From: infra/types/PrivateEndpointSettings.bicep
@description('Type describing the private endpoint settings.')
type PrivateEndpointSettings = {
  @description('The name of the resource group to hold the Private DNS Zone. By default, this uses the same resource group as the resource.')
  dnsResourceGroupName: string

  @description('The name of the private endpoint resource. By default, this uses a prefix of \'pe-\' followed by the name of the resource.')
  name: string

  @description('The name of the resource group to hold the private endpoint. By default, this uses the same resource group as the resource.')
  resourceGroupName: string

  @description('The ID of the subnet to link the private endpoint to.')
  subnetId: string
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

@description('If set, the private endpoint settings for this resource')
param privateEndpointSettings PrivateEndpointSettings?

@description('The list of application identities to be granted owner access to the application resources.')
param ownerIdentities ApplicationIdentity[] = []

@description('The list of application identities to be granted reader access to the application resources.')
param readerIdentities ApplicationIdentity[] = []

@description('Specifies the SKU of the app configuration store.')
param skuName string = 'standard'

// ========================================================================
// VARIABLES
// ========================================================================

/* https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles */

// Allows full access to App Configuration data.
var appConfigurationDataOwnerRoleId = '5ae67dd6-50cb-40e7-96ff-dc2bfa4b606b'

// Allows read access to App Configuration data.
var appConfigurationDataReaderRoleId = '516239f1-63e1-4d78-a4de-a74fb236a071'

var logCategories = [
  'Audit'
  'HttpRequest'
]

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource grantDataOwnerAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in ownerIdentities: if (!empty(id.principalId)) {
  name: guid(appConfigurationDataOwnerRoleId, id.principalId, appConfigStore.id, resourceGroup().name)
  scope: appConfigStore
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', appConfigurationDataOwnerRoleId)
    principalId: id.principalId
  }
}]

resource grantDataReaderAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in readerIdentities: if (!empty(id.principalId)) {
  name: guid(appConfigurationDataReaderRoleId, id.principalId, appConfigStore.id, resourceGroup().name)
  scope: appConfigStore
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', appConfigurationDataReaderRoleId)
    principalId: id.principalId
  }
}]

resource appConfigStore 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: name
  location: location
  properties: {
    // when publicNetworkAccess is Disabled - must pair with build agent to set config values
    publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
  }
  sku: {
    name: skuName
  }
}

module privateEndpoint '../network/private-endpoint.bicep' = if (privateEndpointSettings != null) {
  name: '${name}-private-endpoint'
  scope: resourceGroup(privateEndpointSettings != null ? privateEndpointSettings!.resourceGroupName : resourceGroup().name)
  params: {
    name: privateEndpointSettings != null ? privateEndpointSettings!.name : 'pep-${name}'
    location: location
    tags: tags
    dnsRsourceGroupName: privateEndpointSettings == null ? resourceGroup().name : privateEndpointSettings!.dnsResourceGroupName

    // Dependencies
    linkServiceId: appConfigStore.id
    linkServiceName: appConfigStore.name
    subnetId: privateEndpointSettings != null ? privateEndpointSettings!.subnetId : ''

    // Settings
    dnsZoneName: 'privatelink.azconfig.io'
    groupIds: [ 'configurationStores' ]
  }
}

resource appConfigDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: appConfigStore
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: map(logCategories, (category) => {
      category: category
      enabled: diagnosticSettings!.enableLogs
    })
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}


// ========================================================================
// OUTPUTS
// ========================================================================

output id string = appConfigStore.id
output name string = appConfigStore.name
output app_config_uri string = appConfigStore.properties.endpoint
