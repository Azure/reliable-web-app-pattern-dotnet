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
