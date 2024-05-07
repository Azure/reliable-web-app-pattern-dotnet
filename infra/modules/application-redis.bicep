targetScope = 'resourceGroup'

/*
** An App Service running on a App Service Plan
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

  @description('The token to use for naming resources.  This should be unique to the deployment.')
  resourceToken: string

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

// From: infra/types/RedisUser.bicep
@description('Type describing the user for redis.')
type RedisUser = {
  @description('The object id of the user.')
  objectId: string

  @description('The alias of the user')
  alias: string

  @description('Specify name of built-in access policy to use as assignment.')
  accessPolicy: 'Data Owner' | 'Data Contributor' | 'Data Reader'
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

@description('The tags to associate with this resource.')
param tags object = {}

@description('The users to be added to the redis instance.')
param users RedisUser[]

@description('When deploying a hub, the private endpoints will need this parameter to specify the resource group that holds the Private DNS zones')
param dnsResourceGroupName string = ''

/*
** Dependencies
*/
@description('The name of the App Configuration store to configure for configuration.')
param appConfigurationName string

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

@description('The list of subnets that are used for linking into the virtual network if using network isolation.')
param subnets object = {}

// ========================================================================
// EXISTING RESOURCES
// ========================================================================

resource configStore 'Microsoft.AppConfiguration/configurationStores@2021-10-01-preview' existing = {
  name: appConfigurationName
}

// ========================================================================
// AZURE MODULES
// ========================================================================

module redis '../core/database/azure-cache-for-redis.bicep' = {
  name: 'application-redis-db-${deploymentSettings.resourceToken}'
  params: {
    name: resourceNames.redis
    location: deploymentSettings.location
    diagnosticSettings: diagnosticSettings
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    // vault provided by Hub resource group when network isolated
    redisCacheSku: deploymentSettings.isProduction ? 'Standard' : 'Basic'
    redisCacheFamily: 'C'
    redisCacheCapacity: deploymentSettings.isProduction ? 1 : 0

    privateEndpointSettings: deploymentSettings.isNetworkIsolated
      ? {
          dnsResourceGroupName: dnsResourceGroupName
          name: resourceNames.redisPrivateEndpoint
          resourceGroupName: resourceNames.spokeResourceGroup
          subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id
        }
      : null

    users: users
  }
}

resource redis_config 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  parent: configStore
  name: 'App:RedisCache:ConnectionString'
  properties: {
    value: redis.outputs.connection_string
    tags: tags
  }
  dependsOn: [redis]
}
