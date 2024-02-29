targetScope = 'subscription'

/*
** Azure Monitor Workload
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/DeploymentSettings.bicep
@description('Type that describes the global deployment settings')
type DeploymentSettings = {
  @description('If \'true\', then two regional deployments will be performed.')
  isMultiLocationDeployment: bool
  
  @description('If \'true\', use production SKUs and settings.')
  isProduction: bool

  @description('If \'true\', isolate the workload in a virtual network.')
  isNetworkIsolated: bool
  
  @description('If \'false\', then this is a multi-location deployment for the second location.')
  isPrimaryLocation: bool

  @description('The Azure region to host resources')
  location: string

  @description('The name of the workload.')
  name: string

  @description('The ID of the principal that is being used to deploy resources.')
  principalId: string

  @description('The type of the \'principalId\' property.')
  principalType: 'ServicePrincipal' | 'User'

  @description('The development stage for this application')
  stage: 'dev' | 'prod'

  @description('The common tags that should be used for all created resources')
  tags: object

  @description('The common tags that should be used for all workload resources')
  workloadTags: object
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
