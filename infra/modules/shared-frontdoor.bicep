targetScope = 'subscription'

/*
** Azure Front Door resource for the front-end and API web apps
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

  @description('The primary Azure region to host resources')
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

// From: infra/types/FrontDoorSettings.bicep
@description('Type describing the settings for Azure Front Door.')
type FrontDoorSettings = {
  @description('The name of the Azure Front Door endpoint')
  endpointName: string

  @description('Front Door Id used for traffic restriction')
  frontDoorId: string

  @description('The hostname that can be used to access Azure Front Door content.')
  hostname: string

  @description('The profile name that is used for configuring Front Door routes.')
  profileName: string
}


// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The resource names for the resources to be created.')
param resourceNames object

/*
** Dependencies
*/

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

// ========================================================================
// VARIABLES
// ========================================================================

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, deploymentSettings.workloadTags)

// ========================================================================
// EXISTING RESOURCES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceNames.resourceGroup
}

// ========================================================================
// NEW RESOURCES
// ========================================================================

/*
** Azure Front Door with Web Application Firewall
*/
module frontDoor '../core/security/front-door-with-waf.bicep' = {
  name: 'application-front-door-with-waf'
  scope: resourceGroup
  params: {
    frontDoorEndpointName: resourceNames.frontDoorEndpoint
    frontDoorProfileName: resourceNames.frontDoorProfile
    webApplicationFirewallName: resourceNames.webApplicationFirewall
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Service settings
    diagnosticSettings: diagnosticSettings
    managedRules: deploymentSettings.isProduction ? [
      { name: 'Microsoft_DefaultRuleSet', version: '2.1' }
      { name: 'Microsoft_BotManagerRuleSet', version: '1.0' }
    ] : []
    sku: deploymentSettings.isProduction || deploymentSettings.isNetworkIsolated ? 'Premium' : 'Standard'
  }
}

output settings FrontDoorSettings = {
  endpointName: frontDoor.outputs.endpoint_name
  frontDoorId: frontDoor.outputs.front_door_id
  hostname: frontDoor.outputs.hostname
  profileName: frontDoor.outputs.profile_name
}
