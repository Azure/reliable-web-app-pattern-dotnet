targetScope = 'subscription'

/*
** Enterprise App Patterns Telemetry
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
** Review the enableTelemetry parameter to understand telemetry collection
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

  @description('The name of the principal that is being used to deploy resources.')
  principalName: string

  @description('The type of the \'principalId\' property.')
  principalType: 'ServicePrincipal' | 'User'

  @description('The token to use for naming resources.  This should be unique to the deployment.')
  resourceToken: string

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

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

// ========================================================================
// VARIABLES
// ========================================================================

var telemetryId = '063f9e42-c824-4573-8a47-5f6112612fe2'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource telemetrySubscription 'Microsoft.Resources/deployments@2021-04-01' = {
  name: '${telemetryId}-${deploymentSettings.location}'
  location: deploymentSettings.location
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
      contentVersion: '1.0.0.0'
      resources: {}
    }
  }
}
