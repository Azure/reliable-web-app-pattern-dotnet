targetScope = 'subscription'

/*
** Azure Front Door resource for the front-end and API web apps
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

import { FrontDoorSettings } from '../types/FrontDoorSettings.bicep'
import { DiagnosticSettings } from '../types/DiagnosticSettings.bicep'
import { DeploymentSettings } from '../types/DeploymentSettings.bicep'

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
