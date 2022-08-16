param location string
param resourceToken string
param tags object
param isProd bool
param privateEndpointNameForRedis string
param privateEndpointVnetName string
param privateEndpointSubnetName string

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
  tags: tags
  parent: existingKv
  properties: {
    value: '${redisCache.name}.redis.cache.windows.net:6380,password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
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
  dependsOn: [
    vnet
  ]
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


output keyVaultRedisConnStrName string = kvSecretRedis.name
output privateDnsZoneId string = privateDnsZoneNameForRedis.id
