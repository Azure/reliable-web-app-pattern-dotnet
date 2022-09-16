@description('The id for the user-assigned managed identity that runs deploymentScripts')
param devOpsManagedIdentityId string

@description('Expecting the user-assigned managed identity that represents the API web app. Will become the SQL db admin')
param managedIdentity object

@description('A generated identifier used to create unique resources')
param resourceToken string

@description('Enables the template to choose different SKU by environment')
param isProd bool

param sqlAdministratorLogin string

@secure()
param sqlAdministratorPassword string

@description('Ensures that the idempotent scripts are executed each time the deployment is executed')
param uniqueScriptId string = newGuid()

param location string
param tags object

var sqlServerName = '${resourceToken}-sql-server'

resource allowSqlAdminScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'allowSqlAdminScript'
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity:{
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${devOpsManagedIdentityId}': {}
    }
  }
  properties: {
    forceUpdateTag: uniqueScriptId
    azPowerShellVersion: '7.4'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    arguments: '-SqlServerName \'${sqlServerName}\' -ResourceGroupName \'${resourceGroup().name}\''
    scriptContent: loadTextContent('enableSqlAdminForServer.ps1')
  }
}

resource sqlServer 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
    administrators: {
      login: managedIdentity.name
      principalType: 'User'
      sid: managedIdentity.properties.principalId
      tenantId: managedIdentity.properties.tenantId
    }
    version: '12.0'
  }
  dependsOn:[
    allowSqlAdminScript
  ]
}

var sqlCatalogName = '${resourceToken}-sql-database'
var skuTierName = isProd ? 'Premium' : 'Standard'
var dtuCapacity = isProd ? 125 : 10
var requestedBackupStorageRedundancy = isProd ? 'Geo' : 'Local'
var readScale = isProd ? 'Enabled' : 'Disabled'


resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01-preview' = {
  name: '${sqlServer.name}/${sqlCatalogName}'
  location: location
  tags: union(tags, {
    displayName: sqlCatalogName
  })
  sku: {
    name: skuTierName
    tier: skuTierName
    capacity: dtuCapacity
  }
  properties: {
    requestedBackupStorageRedundancy: requestedBackupStorageRedundancy
    readScale: readScale
  }
}

// To allow applications hosted inside Azure to connect to your SQL server, Azure connections must be enabled. 
// To enable Azure connections, there must be a firewall rule with starting and ending IP addresses set to 0.0.0.0. 
// This recommended rule is only applicable to Azure SQL Database.
// Ref: https://docs.microsoft.com/en-us/azure/azure-sql/database/firewall-configure?view=azuresql#connections-from-inside-azure
resource allowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@2021-11-01-preview' = {
  name: 'AllowAllWindowsAzureIps'
  parent: sqlServer
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

resource createSqlUserScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'createSqlUserScript'
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity:{
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${devOpsManagedIdentityId}': {}
    }
  }
  properties: {
    forceUpdateTag: uniqueScriptId
    azPowerShellVersion: '7.4'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    arguments: '-ServerName \'${sqlServer.name}\' -ResourceGroupName \'${resourceGroup().name}\' -ServerUri \'${sqlServer.properties.fullyQualifiedDomainName}\' -CatalogName \'${sqlCatalogName}\' -ApplicationId \'${managedIdentity.properties.principalId}\' -ManagedIdentityName \'${managedIdentity.name}\' -SqlAdminLogin \'${sqlAdministratorLogin}\' -SqlAdminPwd \'${sqlAdministratorPassword}\' -IsProd ${isProd ? '1' : '0'}'
    scriptContent: loadTextContent('createSqlAcctForManagedIdentity.ps1')
  }
  dependsOn:[
    sqlDatabase
  ]
}

output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlCatalogName string = sqlCatalogName

output sqlServerName string = sqlServer.name
output sqlServerId string = sqlServer.id
output sqlDatabaseName string = sqlDatabase.name
