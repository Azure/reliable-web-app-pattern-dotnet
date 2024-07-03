targetScope = 'resourceGroup'

/*
** Virtual Network Resource
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates a new virtual network, plus diagnostics for the resource.
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
@description('If a DDoS protection plan is in use, the ID of the plan to associate with this virtual network.')
param ddosProtectionPlanId string = ''

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/
@description('The CIDR block to use for the address prefix of this virtual network.')
param addressPrefix string

@description('The set of subnets to use for this resource')
param subnets object[]

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  location: location
  name: name
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [ addressPrefix ]
    }
    ddosProtectionPlan: !empty(ddosProtectionPlanId) ? {
      id: ddosProtectionPlanId
    } : null
    enableDdosProtection: !empty(ddosProtectionPlanId)
    subnets: subnets
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: virtualNetwork
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'VMProtectionAlerts'
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

output id string = virtualNetwork.id
output name string = virtualNetwork.name

output subnets object = toObject(virtualNetwork.properties.subnets, subnet => subnet.name)
