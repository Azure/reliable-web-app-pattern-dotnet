targetScope = 'resourceGroup'

/*
** An App Service running on a pre-existing App Service Plan
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

import { PrivateEndpointSettings } from '../../types/PrivateEndpointSettings.bicep'
import { DiagnosticSettings } from '../../types/DiagnosticSettings.bicep'

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
