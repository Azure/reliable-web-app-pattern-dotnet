param location string
param resourceToken string
param tags object
param isProd bool

var redisCacheSkuName = isProd ? 'Standard' : 'Basic'
var redisCacheFamilyName = isProd ? 'C' : 'C'
var redisCacheCapacity = isProd ? 1 : 0

resource redisCache 'Microsoft.Cache/Redis@2019-07-01' = {
  name: '${resourceToken}-rediscache'
  location: location
  tags: tags
  properties: {
    sku: {
      name: redisCacheSkuName
      family: redisCacheFamilyName
      capacity: redisCacheCapacity
    }
  }
}

resource existingKv 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: 'rc-${resourceToken}-kv' // keyvault name cannot start with a number
  scope: resourceGroup()
}

resource kvSecretRedis 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  name: 'App--RedisCache--ConnectionString'
  parent: existingKv
  properties: {
    value: '${redisCache.name}.redis.cache.windows.net:6380,password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
  }
}

// TODO - should be a param
var vnetname = 'myVirtualNetwork'
// TODO - should be a param
var subnet1Name = 'mySubnet'

resource privateEndpointForRedis 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: 'myRedisPrivateEndpoint'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetname, subnet1Name)
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
}

resource privateDnsZoneName_resource 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'windows.net'
}

resource pvtendpointdnsgroupname 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-07-01' = {
  name: '${privateEndpointForRedis.name}/mydnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneName_resource.id
        }
      }
    ]
  }
}

output keyVaultRedisConnStrName string = kvSecretRedis.name
