@description('The id for the user-assigned managed identity that runs deploymentScripts')
param devOpsManagedIdentityId string

@description('Enables the template to choose different SKU by environment')
param isProd bool

@minLength(1)
@description('The name of the Key Vault that will store AAD secrets for the web app')
param keyVaultName string

@description('The Azure location where this solution is deployed')
param location string

@description('A generated identifier used to create unique resources')
param resourceToken string

@description('Name for private endpoint')
param privateEndpointNameForRedis string

@description('Name of subnet for private endpoint')
param privateEndpointSubnetName string

@description('Name of vnet for private endpoint')
param privateEndpointVnetName string

@description('An object collection that contains annotations to describe the deployed azure resources to improve operational visibility')
param tags object

@description('Ensures that the idempotent scripts are executed each time the deployment is executed')
param uniqueScriptId string = newGuid()

var redisCacheSkuName = isProd ? 'Standard' : 'Basic'
var redisCacheFamilyName = isProd ? 'C' : 'C'
var redisCacheCapacity = isProd ? 1 : 0

resource redisCache 'Microsoft.Cache/Redis@2022-05-01' = {
  name: '${resourceToken}-rediscache'
  location: location
  tags: tags
  properties: {
    redisVersion: '6.0'
    sku: {
      name: redisCacheSkuName
      family: redisCacheFamilyName
      capacity: redisCacheCapacity
    }
    enableNonSslPort: false
    publicNetworkAccess: 'Disabled'
    redisConfiguration: {
      'maxmemory-reserved': '30'
      'maxfragmentationmemory-reserved': '30'
      'maxmemory-delta': '30'
    }
  }
}

resource existingKeyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: keyVaultName
  scope: resourceGroup()

  resource kvSecretRedis 'secrets@2021-11-01-preview' = {
    name: 'App--RedisCache--ConnectionString'
    tags: tags
    properties: {
      value: '${redisCache.name}.redis.cache.windows.net:6380,password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
    }
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-07-01' existing = {
  name: privateEndpointVnetName
}

resource privateEndpointForRedis 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: privateEndpointNameForRedis
  location: location
  tags: tags
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateEndpointSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: redisCache.name
        properties: {
          privateLinkServiceId: redisCache.id
          groupIds: [
            'redisCache'
          ]
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

resource privateDnsZoneNameForRedis 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.redis.cache.windows.net'
  location: 'global'
  tags: tags
}

resource privateDnsZoneNameForRedis_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneNameForRedis
  name: '${privateDnsZoneNameForRedis.name}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource makeRedisAccessibleForDevs 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (!isProd) {
  name: 'makeRedisAccessibleForDevs'
  location: location
  tags: tags
  kind:'AzureCLI'
  identity:{
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${devOpsManagedIdentityId}': {}
    }
  }
  properties: {
    forceUpdateTag: uniqueScriptId
    azCliVersion: '2.37.0'
    retentionInterval: 'P1D'
    scriptContent: loadTextContent('azureRedisCachePublicDevAccess.sh')
    arguments:' --subscription ${subscription().subscriptionId} --resource-group ${resourceGroup().name} --name ${redisCache.name}'
  }
}

output keyVaultRedisConnStrName string = existingKeyVault::kvSecretRedis.name
output privateDnsZoneId string = privateDnsZoneNameForRedis.id
