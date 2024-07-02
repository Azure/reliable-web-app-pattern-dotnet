targetScope = 'resourceGroup'

/*
** App Service Plan
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

import { DiagnosticSettings } from '../../types/DiagnosticSettings.bicep'

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

@description('A type that describes the auto-scale settings via Microsoft.Insights')
type AutoScaleSettings = {
  @description('The minimum number of scale units to provision.')
  minCapacity: int

  @description('The maximum number of scale units to provision.')
  maxCapacity: int

  @description('The CPU percentage at which point to scale in.')
  scaleInThreshold: int?

  @description('The CPU percentage at which point to scale out.')
  scaleOutThreshold: int?
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('If using network isolation, the network isolation settings to use.')
param diagnosticSettings DiagnosticSettings?

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
@description('If set, the auto-scale settings')
param autoScaleSettings AutoScaleSettings?

@allowed([ 'Windows', 'Linux' ])
@description('The OS for the application that will be run on this App Service Plan.  Default is windows.')
param serverType string = 'Windows'

@allowed([ 'B1', 'B2', 'B3', 'P0v3', 'P1v3', 'P2v3', 'P3v3', 'S1', 'S2', 'S3' ])
@description('The SKU to use for the compute platform.')
param sku string = 'B1'

@description('If true, set this App Service Plan to be availability zone redundant.')
param zoneRedundant bool = false

// ========================================================================
// VARIABLES
// ========================================================================

// Default auto-scale settings
var defaultScaleInThreshold = 40
var defaultScaleOutThreshold = 75

// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/patterns-configuration-set#example
var environmentConfigurationMap = {
  B1:   { name: 'B1',   tier: 'Basic',          size: 'B1',   family: 'B'   }
  B2:   { name: 'B2',   tier: 'Basic',          size: 'B2',   family: 'B'   }
  B3:   { name: 'B3',   tier: 'Basic',          size: 'B3',   family: 'B'   }
  P0v3: { name: 'P0v3', tier: 'PremiumV3',      size: 'P0v3', family: 'Pv3' }
  P1v3: { name: 'P1v3', tier: 'PremiumV3',      size: 'P1v3', family: 'Pv3' }
  P2v3: { name: 'P2v3', tier: 'PremiumV3',      size: 'P2v3', family: 'Pv3' }
  P3v3: { name: 'P3v3', tier: 'PremiumV3',      size: 'P3v3', family: 'Pv3' }
  S1:   { name: 'S1',   tier: 'Standard',       size: 'S1',   family: 'S'   }
  S2:   { name: 'S2',   tier: 'Standard',       size: 'S2',   family: 'S'   }
  S3:   { name: 'S3',   tier: 'Standard',       size: 'S3',   family: 'S'   }
}

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: environmentConfigurationMap[sku].name
    tier: environmentConfigurationMap[sku].tier
    size: environmentConfigurationMap[sku].size
    family: environmentConfigurationMap[sku].family
    capacity: (environmentConfigurationMap[sku].tier == 'PremiumV3' && zoneRedundant) ? 3 : 1
  }
  kind: serverType == 'Windows' ? '' : 'linux'
  properties: {
    perSiteScaling: true
    reserved: serverType == 'Linux'
    zoneRedundant: zoneRedundant
  }
}

resource autoScaleRule 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (autoScaleSettings != null) {
  name: '${name}-autoscale'
  location: location
  tags: tags
  properties: {
    targetResourceUri: appServicePlan.id
    enabled: true
    profiles: [
      {
        name: 'Auto created scale condition'
        capacity: {
          minimum: string(zoneRedundant ? 3 : autoScaleSettings!.minCapacity)
          maximum: string(autoScaleSettings!.maxCapacity)
          default: string(zoneRedundant ? 3 : autoScaleSettings!.minCapacity)
        }
        rules: [
          {
            metricTrigger: {
              metricResourceUri: appServicePlan.id
              metricName: 'CpuPercentage'
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: autoScaleSettings.?scaleOutThreshold ?? defaultScaleOutThreshold
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
          }
          {
            metricTrigger: {
              metricResourceUri: appServicePlan.id
              metricName: 'CpuPercentage'
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: autoScaleSettings.?scaleInThreshold ?? defaultScaleInThreshold
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: appServicePlan
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: []
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

output id string = appServicePlan.id
output name string = appServicePlan.name
