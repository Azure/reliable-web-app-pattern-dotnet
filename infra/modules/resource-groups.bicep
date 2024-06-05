targetScope = 'subscription'

/*
** Resource Groups 
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates all the resource groups needed by this deployment
*/

import { DeploymentSettings } from '../types/DeploymentSettings.bicep'

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The global deployment settings')
param deploymentSettings DeploymentSettings

@description('The list of resource names to use')
param resourceNames object

@description('If true, deploy a hub network')
param deployHubNetwork bool

// ========================================================================
// VARIABLES
// ========================================================================

var createHub = deployHubNetwork && resourceNames.hubResourceGroup != resourceNames.resourceGroup && deploymentSettings.isPrimaryLocation
var createSpoke = deploymentSettings.isNetworkIsolated && resourceNames.spokeResourceGroup != resourceNames.resourceGroup

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = if (createHub) {
  name: resourceNames.hubResourceGroup
  location: deploymentSettings.location
  tags: union(deploymentSettings.tags, {
    WorkloadName: 'NetworkHub'
    OpsCommitment: 'Platform operations'
  })
}

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = if (createSpoke) {
  name: resourceNames.spokeResourceGroup
  location: deploymentSettings.location
  tags: union(deploymentSettings.tags, deploymentSettings.workloadTags)
}

resource applicationResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceNames.resourceGroup
  location: deploymentSettings.location
  tags: union(deploymentSettings.tags, deploymentSettings.workloadTags)
}

// ========================================================================
// OUTPUTS
// ========================================================================


output application_resource_group_name string = applicationResourceGroup.name
output spoke_resource_group_name string = createSpoke ? spokeResourceGroup.name : 'spoke-not-created'
output hub_resource_group_name string = createHub ? hubResourceGroup.name : 'hub-not-created'
