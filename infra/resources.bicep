param location string
param environmentName string
param principalId string = ''
param resourceToken string
param tags object

var isProd = endsWith(toLower(environmentName),'prod') || startsWith(toLower(environmentName),'prod')

// Managed Identity
@description('A user-assigned managed identity that is used by the App Service app to communicate with a storage account.')
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'web-${resourceToken}-identity'
  location: location
  tags: tags
}

@description('Built in \'Data Reader\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
// Allows read access to App Configuration data
var appConfigurationRoleDefinitionId = '516239f1-63e1-4d78-a4de-a74fb236a071'

// Role assignment
@description('Grant the \'Data Reader\' role to the user-assigned managed identity, at the scope of the resource group.')
resource appConfigRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(appConfigurationRoleDefinitionId, appConfigSvc.id, resourceToken)
  scope: resourceGroup()
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', appConfigurationRoleDefinitionId)
    principalId: managedIdentity.properties.principalId
    description: 'Grant the "Data Reader" role to the user-assigned managed identity so it can access the storage account.'
  }
}

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: 'rc-${resourceToken}-kv' // keyvault name cannot start with a number
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        objectId: managedIdentity.properties.principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'list'
            'get'
            'set'
          ]
        }
      }
      {
        objectId: principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'all'
          ]
        }
      }
    ]
  }
}

resource baseApiUrlAppConfigSetting 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  parent: appConfigSvc
  name: 'App:RelecloudApi:BaseUri'
  properties: {
    value: 'https://${api.properties.defaultHostName}'
  }
}

resource sqlConnStrAppConfigSetting 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  parent: appConfigSvc
  name: 'App:SqlDatabase:ConnectionString'
  properties: {
    value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlCatalogName};Authentication=Active Directory Default'
  }
}

resource redisConnAppConfigKvRef 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  parent: appConfigSvc
  name: 'App:RedisCache:ConnectionString'
  properties: {
    value: string({
      uri: '${kv.properties.vaultUri}secrets/${kvSecretRedis.name}'
    })
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
  }
}

resource kvSecretRedis 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: kv
  name: 'App--RedisCache--ConnectionString'
  properties: {
    value: '${redisCache.name}.redis.cache.windows.net:6380,password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
  }
}

resource frontEndClientSecretAppCfg 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  parent: appConfigSvc
  name: 'AzureAd:ClientSecret'
  properties: {
    value: string({
      uri: '${kv.properties.vaultUri}secrets/${frontEndClientSecretName}'
    })
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
  }
  dependsOn: [
    check_if_client_secret_exists
  ]
}

var frontEndClientSecretName='AzureAd--ClientSecret'

resource check_if_client_secret_exists 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'check_if_client_secret_exists'
  location: location
  kind:'AzureCLI'
  identity:{
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {} 
    }
  }
  properties: {
    azCliVersion: '2.37.0'
    retentionInterval: 'P1D'
    scriptContent: 'result=$(az keyvault secret list --vault-name ${kv.name} --query "[?name==\'${frontEndClientSecretName}\'].name" -o tsv); if [[ \${#result} -eq 0 ]]; then az keyvault secret set --name \'AzureAd--ClientSecret\' --vault-name ${kv.name} --value 1 --only-show-errors > /dev/null; fi'
    arguments:'--resourceToken \'${resourceToken}\''
  }
}

resource storageAppConfigKvRef 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  parent: appConfigSvc
  name: 'App:StorageAccount:QueueConnectionString'
  properties: {
    value: string({
      uri: '${kv.properties.vaultUri}secrets/${kvSecretStorageAcct.name}'
    })
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
  }
}

resource kvSecretStorageAcct 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: kv
  name: 'App--StorageAccount--QueueConnectionString'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0]};EndpointSuffix=core.windows.net'
  }
}

resource web 'Microsoft.Web/sites@2021-03-01' = {
  name: 'web-${resourceToken}-web-app'
  location: location
  tags: union(tags, {
      'azd-service-name': 'web'
    })
  properties: {
    serverFarmId: webAppServicePlan.id
    siteConfig: {
      alwaysOn: true
      ftpsState: 'FtpsOnly'
    }
    httpsOnly: true
  }
  
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {} 
    }
  }

  resource appSettings 'config' = {
    name: 'appsettings'
    properties: {
      ASPNETCORE_ENVIRONMENT: 'Development'
      AZURE_CLIENT_ID: managedIdentity.properties.clientId
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
      APPLICATIONINSIGHTS_CONNECTION_STRING: webApplicationInsightsResources.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING
      'App:AppConfig:Uri': appConfigSvc.properties.endpoint
    }
  }

  resource logs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: {
        fileSystem: {
          level: 'Verbose'
        }
      }
      detailedErrorMessages: {
        enabled: true
      }
      failedRequestsTracing: {
        enabled: true
      }
      httpLogs: {
        fileSystem: {
          enabled: true
          retentionInDays: 1
          retentionInMb: 35
        }
      }
    }
  }
}

resource api 'Microsoft.Web/sites@2021-01-15' = {
  name: 'api-${resourceToken}-web-app'
  location: location
  tags: union(tags, {
      'azd-service-name': 'api'
    })
  kind: 'app,linux'
  properties: {
    serverFarmId: apiAppServicePlan.id
    siteConfig: {
      alwaysOn: true
      ftpsState: 'FtpsOnly'
    }
    httpsOnly: true
  }

  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {} 
    }
  }

  resource appSettings 'config' = {
    name: 'appsettings'
    properties: {
      WEBSITE_VNET_ROUTE_ALL: '1' 
      // https://docs.microsoft.com/en-us/azure/virtual-network/what-is-ip-address-168-63-129-16
      WEBSITE_DNS_SERVER: '168.63.129.16' 
      ASPNETCORE_ENVIRONMENT: 'Development'
      AZURE_CLIENT_ID: managedIdentity.properties.clientId
      APPLICATIONINSIGHTS_CONNECTION_STRING: apiApplicationInsights.properties.ConnectionString
      'App:AppConfig:Uri': appConfigSvc.properties.endpoint
    }
  }

  resource logs 'config' = {
    name: 'logs'
    properties: {
      applicationLogs: {
        fileSystem: {
          level: 'Verbose'
        }
      }
      detailedErrorMessages: {
        enabled: true
      }
      failedRequestsTracing: {
        enabled: true
      }
      httpLogs: {
        fileSystem: {
          enabled: true
          retentionInDays: 1
          retentionInMb: 35
        }
      }
    }
  }
}

resource appConfigSvc 'Microsoft.AppConfiguration/configurationStores@2022-05-01' = {
  name: '${resourceToken}-appconfig'
  location: location
  sku: {
    name: 'Standard'
  }
}

var appServicePlanSku = (isProd) ?  'P1v2' : 'B1'

resource webAppServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${resourceToken}-web-plan'
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
  }
}

resource apiAppServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${resourceToken}-api-plan'
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
  }
}

resource webAppScaleRule 'Microsoft.Insights/autoscalesettings@2021-05-01-preview' = if (isProd) {
  name: '${resourceToken}-web-plan-autoscale'
  location: location
  properties: {
    targetResourceUri: webAppServicePlan.id
    enabled: true
    profiles: [
      {
        name: 'Auto created scale condition'
        capacity: {
          maximum: '10'
          default: '1'
          minimum: '1'
        }
        rules: [
          {
            metricTrigger: {
              metricResourceUri: webAppServicePlan.id
              metricName: 'CpuPercentage'
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: scaleOutThreshold
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
          }
          {
            metricTrigger: {
              metricResourceUri: webAppServicePlan.id
              metricName: 'CpuPercentage'
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: scaleInThreshold
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
  }
}

var scaleOutThreshold = 85
var scaleInThreshold = 60

resource apiAppScaleRule 'Microsoft.Insights/autoscalesettings@2014-04-01' = {
  name: '${resourceToken}-api-plan-autoscale'
  location: location
  properties: {
    targetResourceUri: apiAppServicePlan.id
    enabled: true
    profiles: [
      {
        name: 'Auto created scale condition'
        capacity: {
          minimum: string(1)
          maximum: string(10)
          default: string(1)
        }
        rules: [
          {
            metricTrigger: {
              metricResourceUri: apiAppServicePlan.id
              metricName: 'CpuPercentage'
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: scaleOutThreshold
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
          }
          {
            metricTrigger: {
              metricResourceUri: apiAppServicePlan.id
              metricName: 'CpuPercentage'
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: scaleInThreshold
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
  }
}

resource webLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: 'web-${resourceToken}-log'
  location: location
  tags: tags
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

module webApplicationInsightsResources './applicationinsights.bicep' = {
  name: 'web-${resourceToken}-app-insights'
  params: {
    resourceToken: resourceToken
    location: location
    tags: tags
    workspaceId: webLogAnalyticsWorkspace.id
  }
}

resource apiLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: 'api-${resourceToken}-log'
  location: location
  tags: tags
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource apiApplicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'api-${resourceToken}-appi'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: apiLogAnalyticsWorkspace.id
  }
}

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

resource sqlServer 'Microsoft.Sql/servers@2021-11-01-preview' = {
  name: '${resourceToken}-sql-server'
  location: location
  properties: {
    administrators: {
      azureADOnlyAuthentication: true
      login: managedIdentity.name
      principalType: 'User'
      sid: managedIdentity.properties.principalId
      tenantId: managedIdentity.properties.tenantId
    }
    publicNetworkAccess: 'Disabled'
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

var storageSku = isProd ? 'Standard_ZRS' : 'Standard_LRS'

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: '${resourceToken}storage' //storage account name cannot contain '-'
  location: location
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'

  resource queueService 'queueServices@2021-09-01' = {
    name: 'default'

    resource queue 'queues@2021-09-01' = {
      name: 'relecloudconcertevents'
    }
  }
}

var subnet1Name = 'mySubnet'
var subnetAppServiceName = 'subnetAppService'
resource vnet 'Microsoft.Network/virtualNetworks@2020-07-01' = {
  name: 'myVirtualNetwork'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnet1Name
        properties: {
          addressPrefix: '10.0.0.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: subnetAppServiceName
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
        }
      }
    ]
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: 'myPrivateEndpoint'
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, subnet1Name)
    }
    privateLinkServiceConnections: [
      {
        name: '${sqlServer.name}/${sqlDatabase.name}'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}


resource privateDnsZoneName_resource 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'windows.net'
  location: 'global'
  dependsOn: [
    vnet
  ]
}

resource privateDnsZoneName_privateDnsZoneName_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneName_resource
  name: '${privateDnsZoneName_resource.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource pvtendpointdnsgroupname 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-07-01' = {
  name: '${privateEndpoint.name}/mydnsgroupname'
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

resource websitename_virtualNetwork 'Microsoft.Web/sites/networkConfig@2019-08-01' = {
  parent: api
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, subnetAppServiceName)
    swiftSupported: true
  }
}

output WEB_URI string = 'https://${web.properties.defaultHostName}'
output API_URI string = 'https://${api.properties.defaultHostName}'
