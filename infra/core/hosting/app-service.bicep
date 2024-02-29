targetScope = 'resourceGroup'

/*
** An App Service running on a pre-existing App Service Plan
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

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

  @description('The name of the private endpoint resource.  By default, this uses a prefix of \'pe-\' followed by the name of the resource.')
  name: string

  @description('The name of the resource group to hold the private endpoint.  By default, this uses the same resource group as the resource.')
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
@description('The name of the App Service Plan to use for compute resources.')
param appServicePlanName string

@description('The ID of a user-assigned managed identity to use as the identity for this resource.  Use a blank string for a system-assigned identity.')
param managedIdentityId string = ''

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

@description('If using VNET integration, the ID of the subnet to route all outbound traffic through.')
param outboundSubnetId string = ''

/*
** Settings
*/
@description('The list of App Settings for this App Service.')
param appSettings object

@description('If true, enable public network access for this resource.')
param enablePublicNetworkAccess bool = true

@description('The list of IP security restrictions to configure.')
param ipSecurityRestrictions object[] = []

@description('If set, the private endpoint settings for this resource')
param privateEndpointSettings PrivateEndpointSettings?

@description('The service prefix to use.')
param servicePrefix string

// ========================================================================
// VARIABLES
// ========================================================================

var identity = !empty(managedIdentityId) ? {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${managedIdentityId}': {}
  }
} : {
  type: 'SystemAssigned'
}

var logCategories = [
  'AppServiceAppLogs'
  'AppServiceConsoleLogs'
  'AppServiceHTTPLogs'
  'AppServicePlatformLogs'
]

var defaultAppServiceProperties = {
  clientAffinityEnabled: false
  httpsOnly: true
  publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
  serverFarmId: resourceId('Microsoft.Web/serverfarms', appServicePlanName)
  siteConfig: {
    alwaysOn: true
    detailedErrorLoggingEnabled: diagnosticSettings.enableLogs
    httpLoggingEnabled: diagnosticSettings.enableLogs
    requestTracingEnabled: diagnosticSettings.enableLogs
    ftpsState: 'Disabled'
    ipSecurityRestrictions: ipSecurityRestrictions
    minTlsVersion: '1.2'
  }
}

var networkIsolationAppServiceProperties = !empty(outboundSubnetId) ? {
  virtualNetworkSubnetId: outboundSubnetId
  vnetRouteAllEnabled: true
} : {}

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': servicePrefix })
  kind: 'web'
  identity: identity
  properties: union(defaultAppServiceProperties, networkIsolationAppServiceProperties)

  resource configAppSettings 'config' = {
    name: 'appsettings'
    properties: appSettings
  }

  resource configLogs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: {
        fileSystem: { level: 'Verbose' }
      }
      detailedErrorMessages: {
        enabled: true
      }
      failedRequestsTracing: {
        enabled: true
      }
      httpLogs: {
        fileSystem: {
          enabled: true
          retentionInDays: 2
          retentionInMb: 100
        }
      }
    }
    dependsOn: [
      configAppSettings
    ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: appService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: map(logCategories, (category) => {
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

module privateEndpoint '../network/private-endpoint.bicep' = if (privateEndpointSettings != null) {
  name: '${name}-private-endpoint'
  scope: resourceGroup(privateEndpointSettings != null ? privateEndpointSettings!.resourceGroupName : resourceGroup().name)
  params: {
    name: privateEndpointSettings != null ? privateEndpointSettings!.name : 'pep-${name}'
    location: location
    tags: tags
    dnsRsourceGroupName: privateEndpointSettings == null ? resourceGroup().name : privateEndpointSettings!.dnsResourceGroupName

    // Dependencies
    linkServiceId: appService.id
    linkServiceName: appService.name
    subnetId: privateEndpointSettings != null ? privateEndpointSettings!.subnetId : ''

    // Settings
    dnsZoneName: 'privatelink.azurewebsites.net'
    groupIds: [ 'sites' ]
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = appService.id
output name string = appService.name
output hostname string = appService.properties.defaultHostName
output uri string = 'https://${appService.properties.defaultHostName}'
