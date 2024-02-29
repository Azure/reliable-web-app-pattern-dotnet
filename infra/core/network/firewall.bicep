targetScope = 'resourceGroup'

/*
** Azure Firewall Resource
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** A fully stateful firewall as a service that provides both east-west and north-south traffic inspection.
** https://learn.microsoft.com/en-us/azure/firewall/overview
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
@description('The resource ID of the Firewall Policy that should be attached to this firewall.')
param firewallPolicyId string = ''

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

@description('The ID of the subnet to link the firewall to.')
param subnetId string

/*
** Settings
*/
@description('The name of the Public IP Address resource to use for outbound connectivity.  If not specified, a name will be created.')
param publicIpAddressName string = ''

@allowed([ 'Standard', 'Premium' ])
@description('The pricing SKU to configure.')
param sku string = 'Standard'

@description('The operational mode for threat intelligence.  The default is to alert, but not deny traffic.')
param threatIntelMode string = 'Alert'

@description('If true, the resource should be redundant across all availability zones.')
param zoneRedundant bool = false

/*
** The firewall rules to install.
*/
@description('The list of application rule collections to configure')
param applicationRuleCollections object[] = []

@description('The list of NAT rule collections to configure.')
param natRuleCollections object[] = []

@description('The list of network rule collections to configure.')
param networkRuleCollections object[] = []

// ========================================================================
// VARIABLES
// ========================================================================

var pipName = !empty(publicIpAddressName) ? publicIpAddressName : 'pip-${name}'

var logCategories = [
  'AZFWApplicationRuleAggregation'
  'AZFWNatRuleAggregation'
  'AZFWNetworkRuleAggregation'
  'AZFWThreatIntel'
  'AZFWApplicationRule'
  'AZFWFlowTrace'
  'AZFWIdpsSignature'
  'AZFWNatRule'
  'AZFWNetworkRule'
]

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

resource azureFirewall 'Microsoft.Network/azureFirewalls@2022-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    firewallPolicy: !empty(firewallPolicyId) ? {
      id: firewallPolicyId
    } : null
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIpAddress.outputs.id
          }
        }
      }
    ]
    sku: {
      name: 'AZFW_VNet'
      tier: sku
    }
    applicationRuleCollections: applicationRuleCollections
    natRuleCollections: natRuleCollections
    networkRuleCollections: networkRuleCollections
    threatIntelMode: threatIntelMode
  }
  zones: zoneRedundant ? [ '1', '2', '3' ] : []
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: azureFirewall
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

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = azureFirewall.id
output name string = azureFirewall.name

output hostname string = publicIpAddress.outputs.hostname
output internal_ip_address string = azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
