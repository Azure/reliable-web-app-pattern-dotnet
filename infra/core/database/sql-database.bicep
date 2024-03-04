targetScope = 'resourceGroup'

/*
** SQL Database on an existing SQL Server
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

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

// From: infra/types/PrivateEndpointSettings.bicep
@description('Type describing the private endpoint settings.')
type PrivateEndpointSettings = {
  @description('The name of the resource group to hold the Private DNS Zone. By default, this uses the same resource group as the resource.')
  dnsResourceGroupName: string
  
  @description('The name of the private endpoint resource.  By default, this uses a prefix of \'pe-\' followed by the name of the resource.')
  name: string

  @description('The name of the resource group to hold the private endpoint.  By default, this uses the same resource group as the resource.')
  resourceGroupName: string

  @description('The ID of the subnet to link the private endpoint to.')
  subnetId: string
}

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

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = sqlDatabase.id
output name string = sqlDatabase.name
output connection_string string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabase.name};Authentication=Active Directory Default; Connect Timeout=180'

output sql_server_id string = sqlServer.id
output sql_server_name string = sqlServer.name
output sql_server_hostname string = sqlServer.properties.fullyQualifiedDomainName
