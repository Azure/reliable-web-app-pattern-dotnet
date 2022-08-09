@description('A user assigned managed identity object')
param managedIdentity object
param location string
param resourceToken string
param tags object
param isProd bool

@description('The objectId of the user executing the deployment')
param principalId string = ''

param sqlAdministratorLogin string

@secure()
param sqlAdministratorPassword string

resource sqlServer 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: '${resourceToken}-sql-server'
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
  kind: 'AzurePowerShell'
  properties: {

    environmentVariables: [
      {
        name: 'SERVER_NAME'
        value: sqlServer.properties.fullyQualifiedDomainName
      }
      {
        name: 'DATABASE_NAME'
        value: sqlCatalogName
      }
      {
        name: 'USER_NAME'
        value: sqlAdministratorLogin
      }
      {
        name: 'PASSWORD'
        value: sqlAdministratorPassword
      }
      {
        name: 'QUERY'
        value: 'IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N\'${managedIdentity.name}\'); CREATE USER [${managedIdentity.name}] FROM EXTERNAL PROVIDER; ALTER ROLE db_owner ADD MEMBER [${managedIdentity.name}];'
      }
    ]
    azPowerShellVersion: '7.4'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    scriptContent:'Install-Module -Name SqlServer -Force; Import-Module -Name SqlServer; Invoke-Sqlcmd -ServerInstance $ENV:SERVER_NAME -database $ENV:DATABASE_NAME -username $ENV:USER_NAME -password "$ENV:PASSWORD" -query $ENV:QUERY'
  }
}


output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlCatalogName string = sqlCatalogName

output sqlServerName string = sqlServer.name
output sqlServerId string = sqlServer.id
output sqlDatabaseName string = sqlDatabase.name
