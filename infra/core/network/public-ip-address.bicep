targetScope = 'resourceGroup'

/*
** Public IP Address
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates a public IP address and diagnostics resource.
*/

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
@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/
@allowed([ 'Dynamic', 'Static' ])
@description('The public IP address allocation method.  The default is dynamic allocation.')
param allocationMethod string = 'Dynamic'

@description('The DNS label for the resource.  This will become a domain name of domainlabel.region.cloudapp.azure.com')
param domainNameLabel string

@allowed([ 'IPv4', 'IPv6'])
@description('The type of public IP address to generate')
param ipAddressType string = 'IPv4'

@allowed([ 'Basic', 'Standard' ])
param sku string = 'Basic'

@allowed([ 'Regional', 'Global' ])
param tier string = 'Regional'

@description('True if you want the resource to be zone redundant')
param zoneRedundant bool = false

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  location: location
  name: name
  tags: tags
  properties: {
    ddosSettings: {
      protectionMode: 'VirtualNetworkInherited'
    }
    dnsSettings: {
      domainNameLabel: domainNameLabel
    }
    publicIPAddressVersion: ipAddressType
    publicIPAllocationMethod: allocationMethod
    idleTimeoutInMinutes: 4
  }
  sku: {
    name: sku
    tier: tier
  }
  zones: zoneRedundant ? [ '1', '2', '3' ] : []
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: publicIpAddress
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: map( [ 'DDoSMitigationFlowLogs', 'DDoSMitigationReports', 'DDoSProtectionNotifications' ], (category) => {
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

output id string = publicIpAddress.id
output name string = publicIpAddress.name

output hostname string = publicIpAddress.properties.dnsSettings.fqdn
