targetScope = 'subscription'

/*
** Enterprise App Patterns Telemetry
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
** Review the enableTelemetry parameter to understand telemetry collection
*/

import { DeploymentSettings } from '../types/DeploymentSettings.bicep'

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
