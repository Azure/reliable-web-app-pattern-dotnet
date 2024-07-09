targetScope = 'subscription'

/*
** Application Infrastructure
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
@description('The ID of the Application Insights resource to use for App Service logging.')
param applicationInsightsId string = ''

@description('When deploying a hub, the private endpoints will need this parameter to specify the resource group that holds the Private DNS zones')
param dnsResourceGroupName string = ''

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

@description('The list of subnets that are used for linking into the virtual network if using network isolation.')
param subnets object = {}

@description('The settings for a pre-configured Azure Front Door that provides WAF for App Services.')
param frontDoorSettings FrontDoorSettings

/*
** Settings
*/

@description('The IP address of the current system.  This is used to set up the firewall for Key Vault and SQL Server if in development mode.')
param clientIpAddress string = ''

@description('If true, use a common App Service Plan.  If false, use a separate App Service Plan per App Service.')
param useCommonAppServicePlan bool

// ========================================================================
// VARIABLES
// ========================================================================

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, deploymentSettings.workloadTags)

// If the sqlResourceGroup != the application resource group, don't create a server.
var createSqlServer = resourceNames.sqlResourceGroup == resourceNames.resourceGroup

// Budget amounts
//  All values are calculated in dollars (rounded to nearest dollar) in the South Central US region.
var budget = {
  sqlDatabase: deploymentSettings.isProduction ? 457 : 15
  appServicePlan: (deploymentSettings.isProduction ? 690 : 55) * (useCommonAppServicePlan ? 1 : 2)
  virtualNetwork: deploymentSettings.isNetworkIsolated ? 4 : 0
  privateEndpoint: deploymentSettings.isNetworkIsolated ? 9 : 0
  frontDoor: deploymentSettings.isProduction || deploymentSettings.isNetworkIsolated ? 335 : 38
}
var budgetAmount = reduce(map(items(budget), (obj) => obj.value), 0, (total, amount) => total + amount)

// describes the Azure Storage container where ticket images will be stored after they are rendered during purchase
var ticketContainerName = 'tickets'

// Built-in Azure Contributor role
var contributorRole = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

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
** Identities used by the application.
*/
module ownerManagedIdentity '../core/identity/managed-identity.bicep' = {
  name: 'owner-managed-identity-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.ownerManagedIdentity
    location: deploymentSettings.location
    tags: moduleTags
  }
}

module appManagedIdentity '../core/identity/managed-identity.bicep' = {
  name: 'application-managed-identity-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.appManagedIdentity
    location: deploymentSettings.location
    tags: moduleTags
  }
}

module ownerManagedIdentityRoleAssignment '../core/identity/resource-group-role-assignment.bicep' = {
  name: 'owner-managed-identity-role-assignment-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    identityName: ownerManagedIdentity.outputs.name
    roleId: contributorRole
    roleDescription: 'Grant the "Contributor" role to the user-assigned managed identity so it can run deployment scripts.'
  }
}

/*
** App Configuration - used for storing configuration data
*/
module appConfiguration '../core/config/app-configuration.bicep' = {
  name: 'application-app-configuration-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.appConfiguration
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
    ownerIdentities: [
      { principalId: deploymentSettings.principalId, principalType: deploymentSettings.principalType }
      { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.appConfigurationPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id

    } : null
    readerIdentities: [
      { principalId: appManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
  }
}

/*
** Key Vault - used for storing configuration secrets.
** This vault is deployed with the application when not using Network Isolation.
*/
module keyVault '../core/security/key-vault.bicep' = if (!deploymentSettings.isNetworkIsolated) {
  name: 'application-key-vault-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.keyVault
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: true
    ownerIdentities: [
      { principalId: deploymentSettings.principalId, principalType: deploymentSettings.principalType }
      { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.keyVaultPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id
    } : null
    readerIdentities: [
      { principalId: appManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
  }
}

/*
** SQL Database
*/
module sqlServer '../core/database/sql-server.bicep' = if (createSqlServer) {
  name: 'application-sql-server-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.sqlServer
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    managedIdentityName: ownerManagedIdentity.outputs.name

    // Settings
    firewallRules: !deploymentSettings.isProduction && !empty(clientIpAddress) ? {
      allowedIpAddresses: [ '${clientIpAddress}/32' ]
    } : null
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
  }
}

module sqlDatabase '../core/database/sql-database.bicep' = {
  name: 'application-sql-database-${deploymentSettings.resourceToken}'
  scope: az.resourceGroup(resourceNames.sqlResourceGroup)
  params: {
    name: resourceNames.sqlDatabase
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    sqlServerName: createSqlServer ? sqlServer.outputs.name : resourceNames.sqlServer

    // Settings
    diagnosticSettings: diagnosticSettings
    dtuCapacity: deploymentSettings.isProduction ? 125 : 10
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.sqlDatabasePrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id
    } : null
    sku: deploymentSettings.isProduction ? 'Premium' : 'Standard'
    zoneRedundant: deploymentSettings.isProduction
    users: deploymentSettings.isProduction ? [] : [ 
      {
        principalId: deploymentSettings.principalId
        principalName: deploymentSettings.principalName
      } ]
    managedIdentityName: ownerManagedIdentity.outputs.name
  }
}

/*
** App Services
*/
module commonAppServicePlan '../core/hosting/app-service-plan.bicep' = if (useCommonAppServicePlan) {
  name: 'application-app-service-plan-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.commonAppServicePlan
    location: deploymentSettings.location
    tags: moduleTags
    
    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    autoScaleSettings: deploymentSettings.isProduction ? { maxCapacity: 10, minCapacity: 3 } : null
    diagnosticSettings: diagnosticSettings
    sku: deploymentSettings.isProduction ? 'P1v3' : 'B1'
    zoneRedundant: deploymentSettings.isProduction
  }
}

module webService './application-appservice.bicep' = {
  name: 'application-webservice-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    // mapping code projects to web apps by tags matching names from azure.yaml
    tags: moduleTags
    
    // Dependencies
    appConfigurationName: appConfiguration.outputs.name
    applicationInsightsId: applicationInsightsId
    appServicePlanName: useCommonAppServicePlan ? commonAppServicePlan.outputs.name : resourceNames.webAppServicePlan
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    // uses ownerManagedIdentity with code first schema and seeding operations
    // separate approach will be researched by 1852428
    managedIdentityName: ownerManagedIdentity.outputs.name

    // Settings
    appServiceName: resourceNames.webAppService
    outboundSubnetId: deploymentSettings.isNetworkIsolated ? subnets[resourceNames.spokeWebOutboundSubnet].id : ''
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.webAppServicePrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokeWebInboundSubnet].id
    } : null
    restrictToFrontDoor: frontDoorSettings.frontDoorId
    servicePrefix: 'web-callcenter-service'
    useExistingAppServicePlan: useCommonAppServicePlan
  }
}

module webServiceFrontDoorRoute '../core/security/front-door-route.bicep' = if (deploymentSettings.isPrimaryLocation) {
  name: 'web-service-front-door-route-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    frontDoorEndpointName: frontDoorSettings.endpointName
    frontDoorProfileName: frontDoorSettings.profileName
    healthProbeMethod:'GET'
    originPath: '/api/'
    originPrefix: 'web-service'
    serviceAddress: webService.outputs.app_service_hostname
    routePattern: '/api/*'
    privateLinkSettings: deploymentSettings.isNetworkIsolated ? {
      privateEndpointResourceId: webService.outputs.app_service_id
      linkResourceType: 'sites'
      location: deploymentSettings.location
    } : {}
  }
}

module webFrontend './application-appservice.bicep' = {
  name: 'application-webfrontend-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    deploymentSettings: deploymentSettings
    diagnosticSettings: diagnosticSettings
    // mapping code projects to web apps by tags matching names from azure.yaml
    tags: moduleTags
    
    // Dependencies
    appConfigurationName: appConfiguration.outputs.name
    applicationInsightsId: applicationInsightsId
    appServicePlanName: useCommonAppServicePlan ? commonAppServicePlan.outputs.name : resourceNames.webAppServicePlan
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    managedIdentityName: appManagedIdentity.outputs.name

    // Settings
    appServiceName: resourceNames.webAppFrontend
    outboundSubnetId: deploymentSettings.isNetworkIsolated ? subnets[resourceNames.spokeWebOutboundSubnet].id : ''
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.webAppFrontendPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokeWebInboundSubnet].id
    } : null
    restrictToFrontDoor: frontDoorSettings.frontDoorId
    servicePrefix: 'web-callcenter-frontend'
    useExistingAppServicePlan: useCommonAppServicePlan
  }
}

module webFrontendFrontDoorRoute '../core/security/front-door-route.bicep' = if (deploymentSettings.isPrimaryLocation) {
  name: 'web-frontend-front-door-route-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    frontDoorEndpointName: frontDoorSettings.endpointName
    frontDoorProfileName: frontDoorSettings.profileName
    healthProbeMethod:'GET'
    originPath: '/'
    originPrefix: 'web-frontend'
    serviceAddress: webFrontend.outputs.app_service_hostname
    routePattern: '/*'
    privateLinkSettings: deploymentSettings.isNetworkIsolated ? {
      privateEndpointResourceId: webFrontend.outputs.app_service_id
      linkResourceType: 'sites'
      location: deploymentSettings.location
    } : {}
  }
}

/*
** Azure Cache for Redis
*/

module redis '../core/database/azure-cache-for-redis.bicep' = {
  name: 'application-redis-db-${deploymentSettings.resourceToken}'
  scope: resourceGroup
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

    users: deploymentSettings.principalId == null ? [
      {
        alias: ownerManagedIdentity.name
        objectId: ownerManagedIdentity.outputs.principal_id
        accessPolicy: 'Data Contributor'
      }
    ] : [
      {
        alias: ownerManagedIdentity.name
        objectId: ownerManagedIdentity.outputs.principal_id
        accessPolicy: 'Data Contributor'
      }
      {
        alias: deploymentSettings.principalId
        objectId: deploymentSettings.principalId
        accessPolicy: 'Data Contributor'
      }
    ]
  }
}

/*
** Azure Storage
*/

module storageAccount '../core/storage/storage-account.bicep' = {
  name: 'application-storage-account-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    location: deploymentSettings.location
    name: resourceNames.storageAccount

    // Settings
    allowSharedKeyAccess: false
    enablePublicNetworkAccess: false
    ownerIdentities: [
      { principalId: deploymentSettings.principalId, principalType: deploymentSettings.principalType }
      { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal' }
    ]
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.storageAccountPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id
    } : null
  }
}

module storageAccountContainer '../core/storage/storage-account-blob.bicep' = {
  name: 'application-storage-account-container-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.storageAccountContainer
    storageAccountName: storageAccount.outputs.name
    diagnosticSettings: diagnosticSettings
    containers: [
      { name: ticketContainerName }
    ]
  }
}

module approveFrontDoorPrivateLinks '../core/security/front-door-route-approval.bicep' = if (deploymentSettings.isNetworkIsolated && deploymentSettings.isPrimaryLocation) {
  name: 'approve-front-door-routes-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    location: deploymentSettings.location
    managedIdentityName: ownerManagedIdentityRoleAssignment.outputs.identity_name
  }
  // private endpoint approval between front door and web app depends on both resources
  dependsOn: [
    webService
    webServiceFrontDoorRoute
    webFrontend
    webFrontendFrontDoorRoute
  ]
}

module applicationBudget '../core/cost-management/budget.bicep' = {
  name: 'application-budget-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.budget
    amount: budgetAmount
    contactEmails: [
      deploymentSettings.tags['azd-owner-email']
    ]
    resourceGroups: union([ resourceGroup.name ], deploymentSettings.isNetworkIsolated ? [ resourceNames.spokeResourceGroup ] : [])
  }
}

module aiResources 'ai-resources.bicep' = if (deploymentSettings.isPrimaryLocation) {
  name: 'ai-resources-${deploymentSettings.resourceToken}'
  params: {
    bypass: 'AzureServices'
    clientIpAddress: clientIpAddress
    resourceNames: resourceNames
    deploymentSettings: deploymentSettings
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    diagnosticSettings: diagnosticSettings
    dnsResourceGroupName: dnsResourceGroupName
    servicePrefix: 'pyweb'
    useCommonAppServicePlan: useCommonAppServicePlan
    managedIdentityName: ownerManagedIdentity.outputs.name // principal_id
    subnets: subnets
  }
  dependsOn:[
    webService
  ]
}

// ========================================================================
// OUTPUTS
// ========================================================================

output app_config_uri string = appConfiguration.outputs.app_config_uri
output key_vault_name string = deploymentSettings.isNetworkIsolated ? resourceNames.keyVault : keyVault.outputs.name

output owner_managed_identity_id string = ownerManagedIdentity.outputs.id
output app_managed_identity_id string = appManagedIdentity.outputs.id

output service_managed_identities object[] = [
  { principalId: ownerManagedIdentity.outputs.principal_id, principalType: 'ServicePrincipal', role: 'owner'       }
  { principalId: appManagedIdentity.outputs.principal_id,   principalType: 'ServicePrincipal', role: 'application' }
]

output service_web_endpoints string[] = [ deploymentSettings.isPrimaryLocation ? webFrontendFrontDoorRoute.outputs.endpoint : webFrontend.outputs.app_service_uri ]
output web_uri string = deploymentSettings.isPrimaryLocation ? webFrontendFrontDoorRoute.outputs.uri : webFrontend.outputs.app_service_uri

output sql_server_name string = sqlServer.outputs.name
output sql_database_name string = sqlDatabase.outputs.name
