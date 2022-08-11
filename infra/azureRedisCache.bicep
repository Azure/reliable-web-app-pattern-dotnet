param location string
param resourceToken string
param tags object
param isProd bool

var redisCacheSkuName = isProd ? 'Standard' : 'Basic'
var redisCacheFamilyName = isProd ? 'C' : 'C'
var redisCacheCapacity = isProd ? 0 : 0

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

output keyVaultRedisConnStrName string = kvSecretRedis.name
