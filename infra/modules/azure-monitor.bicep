targetScope = 'subscription'

/*
** Azure Monitor Workload
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

import { DiagnosticSettings } from '../types/DiagnosticSettings.bicep'
import { DeploymentSettings } from '../types/DeploymentSettings.bicep'

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The resource names for the resources to be created.')
param resourceNames object

@description('The name of the resource group which should hold Azure Monitor resources.')
param resourceGroupName string

// ========================================================================
// VARIABLES
// ========================================================================

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, {
  WorkloadName: deploymentSettings.name
  Environment: deploymentSettings.stage
  OwnerName: deploymentSettings.tags['azd-owner-email']
  ServiceClass: deploymentSettings.isProduction ? 'Silver' : 'Dev'
  OpsCommitment: 'Workload operations'
})

// ========================================================================
// AZURE MODULES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceGroupName
}

module logAnalytics '../core/monitor/log-analytics-workspace.bicep' = {
  name: 'workload-log-analytics'
  scope: resourceGroup
  params: {
    name: resourceNames.logAnalyticsWorkspace
    location: deploymentSettings.location
    tags: moduleTags

    // Settings
    sku: 'PerGB2018'
  }
}

module applicationInsights '../core/monitor/application-insights.bicep' = {
  name: 'workload-application-insights'
  scope: resourceGroup
  params: {
    name: resourceNames.applicationInsights
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalytics.outputs.id 

    // Settings
    kind: 'web'
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output application_insights_id string = applicationInsights.outputs.id
output log_analytics_workspace_id string = logAnalytics.outputs.id
