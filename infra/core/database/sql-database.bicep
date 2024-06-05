targetScope = 'resourceGroup'

/*
** SQL Database on an existing SQL Server
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

import { DiagnosticSettings } from '../../types/DiagnosticSettings.bicep'
import { PrivateEndpointSettings } from '../../types/PrivateEndpointSettings.bicep'
import { UserIdentity } from '../../types/UserIdentity.bicep'

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The Azure region for the resource.')
param location string

@description('The name of the primary resource')
param name string

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Dependencies
*/
@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

@description('The SQL Server resource name.')
param sqlServerName string

/*
** Settings
*/
@description('The number of DTUs to allocate to the database.')
param dtuCapacity int

@description('If set, the private endpoint settings for this resource')
param privateEndpointSettings PrivateEndpointSettings?

@allowed([ 'Basic', 'Standard', 'Premium' ])
@description('The service tier to use for the database.')
param sku string = 'Basic'

param users UserIdentity[] = []
param managedIdentityName string

@description('If true, enable availability zone redundancy.')
param zoneRedundant bool = false

// ========================================================================
// VARIABLES
// ========================================================================

var logCategories = [
  'SQLSecurityAuditEvents'
  'DevOpsOperationsAudit'
  'AutomaticTuning'
  'Blocks'
  'DatabaseWaitStatistics'
  'Deadlocks'
  'Errors'
  'QueryStoreRuntimeStatistics'
  'QueryStoreWaitStatistics'
  'SQLInsights'
  'Timeouts'
]

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' existing = {
  name: sqlServerName
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  name: name
  parent: sqlServer
  location: location
  tags: union(tags, { displayName: name })
  sku: {
    name: sku
    tier: sku
    capacity: sku == 'Basic' ? 5 : dtuCapacity
  }
  properties: {
    requestedBackupStorageRedundancy: zoneRedundant ? 'Zone' : 'Local'
    readScale: sku == 'Premium' ? 'Enabled' : 'Disabled'
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: zoneRedundant
  }
}

module privateEndpoint '../network/private-endpoint.bicep' = if (privateEndpointSettings != null) {
  name: '${name}-sql-private-endpoint'
  scope: resourceGroup(privateEndpointSettings != null ? privateEndpointSettings!.resourceGroupName : resourceGroup().name)
  params: {
    name: privateEndpointSettings != null ? privateEndpointSettings!.name : 'pep-${name}'
    location: location
    tags: tags
    dnsRsourceGroupName: privateEndpointSettings == null ? resourceGroup().name : privateEndpointSettings!.dnsResourceGroupName


    // Dependencies
    linkServiceId: sqlServer.id
    linkServiceName: '${sqlServer.name}/${sqlDatabase.name}'
    subnetId: privateEndpointSettings != null ? privateEndpointSettings!.subnetId : ''

    // Settings
    dnsZoneName: 'privatelink${az.environment().suffixes.sqlServerHostname}'
    groupIds: [ 'sqlServer' ]
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: sqlDatabase
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: map(logCategories, (category) => {
      category: category
      enabled: diagnosticSettings!.enableLogs
    })
    metrics: [
      {
        category: 'AllMetrics'
        enabled: diagnosticSettings!.enableMetrics
      }
    ]
  }
}

module sqluser 'create-sql-user-and-role.bicep' = [for user in users: {
  name: 'sqluser-${guid(location, user.principalId, user.principalName, name, sqlServer.name)}'
  params: {
    managedIdentityId: managedIdentity.id
    principalId: user.principalId
    principalName: user.principalName
    sqlDatabaseName: name
    location: location
    sqlServerName: sqlServer.name
    databaseRoles: ['db_owner']
  }
  dependsOn: [ sqlDatabase ]
}]

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = sqlDatabase.id
output name string = sqlDatabase.name
output connection_string string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabase.name};Authentication=Active Directory Default; Connect Timeout=180'

output sql_server_id string = sqlServer.id
output sql_server_name string = sqlServer.name
output sql_server_hostname string = sqlServer.properties.fullyQualifiedDomainName
