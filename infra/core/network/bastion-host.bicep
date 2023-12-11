targetScope = 'resourceGroup'

/*
** Bastion Host
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates a bastion host and diagnostics.
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

@description('The ID of the subnet to link the bastion host to.')
param subnetId string

/*
** Settings
*/
@description('The name of the public IP address resource to create.  If not specified, a name will be generated.')
param publicIpAddressName string = ''

@allowed([ 'Basic', 'Standard' ])
@description('The pricing SKU to choose.')
param sku string = 'Basic'

@description('If true, enable availability zone redundancy.')
param zoneRedundant bool = false

// ========================================================================
// VARIABLES
// ========================================================================

var pipName = !empty(publicIpAddressName) ? publicIpAddressName : 'pip-${name}'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

module publicIpAddress '../network/public-ip-address.bicep' = {
  name: pipName
  params: {
    location: location
    name: pipName
    tags: tags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    allocationMethod: 'Static'
    diagnosticSettings: diagnosticSettings
    domainNameLabel: name
    ipAddressType: 'IPv4'
    sku: 'Standard'
    tier: 'Regional'
    zoneRedundant: zoneRedundant
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2022-11-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    enableTunneling: sku == 'Standard' ? true : false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddress.outputs.id
          }
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: bastionHost
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'BastionAuditLogs'
        enabled: diagnosticSettings!.enableLogs
      }
    ]
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

output id string = bastionHost.id
output name string = bastionHost.name

output hostname string = publicIpAddress.outputs.hostname
