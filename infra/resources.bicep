@description('Enables the template to choose different SKU by environment')
param isProd bool

@description('The id for the user-assigned managed identity that runs deploymentScripts')
param devOpsManagedIdentityId string

param location string

@description('The user running the deployment will be given access to the deployed resources such as Key Vault and App Config svc')
param principalId string = ''

@description('A generated identifier used to create unique resources')
param resourceToken string
param tags object

@description('A user-assigned managed identity that is used by the App Service app')
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'web-${resourceToken}-identity'
  location: location
  tags: tags
}

@description('Ensures that the idempotent scripts are executed each time the deployment is executed')
param uniqueScriptId string = newGuid()

@description('Built in \'Data Reader\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var appConfigurationRoleDefinitionId = '516239f1-63e1-4d78-a4de-a74fb236a071'

@description('Grant the \'Data Reader\' role to the user-assigned managed identity, at the scope of the resource group.')
resource appConfigRoleAssignmentForWebApps 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(appConfigurationRoleDefinitionId, appConfigSvc.id, managedIdentity.name, resourceToken)
  scope: resourceGroup()
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', appConfigurationRoleDefinitionId)
    principalId: managedIdentity.properties.principalId
    description: 'Grant the "Data Reader" role to the user-assigned managed identity so it can access the azure app configuration service.'
  }
}

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: 'rc-${resourceToken}-kv' // keyvault name cannot start with a number
  location: location
  tags: tags
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
  dependsOn: [
    openConfigSvcsForEdits
  ]
}

resource sqlConnStrAppConfigSetting 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  parent: appConfigSvc
  name: 'App:SqlDatabase:ConnectionString'
  properties: {
    value: 'Server=tcp:${sqlSetup.outputs.sqlServerFqdn},1433;Initial Catalog=${sqlSetup.outputs.sqlCatalogName};Authentication=Active Directory Default'
  }
  dependsOn: [
    openConfigSvcsForEdits
  ]
}

resource redisConnAppConfigKvRef 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  parent: appConfigSvc
  name: 'App:RedisCache:ConnectionString'
  properties: {
    value: string({
      uri: '${kv.properties.vaultUri}secrets/${redisSetup.outputs.keyVaultRedisConnStrName}'
    })
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
  }
  dependsOn: [
    openConfigSvcsForEdits
  ]
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
    checkIfClientSecretExists
  ]
}

var frontEndClientSecretName = 'AzureAd--ClientSecret'

resource checkIfClientSecretExists 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'checkIfClientSecretExists'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.37.0'
    retentionInterval: 'P1D'
    scriptContent: 'result=$(az keyvault secret list --vault-name ${kv.name} --query "[?name==\'${frontEndClientSecretName}\'].name" -o tsv); if [[ \${#result} -eq 0 ]]; then az keyvault secret set --name \'AzureAd--ClientSecret\' --vault-name ${kv.name} --value 1 --only-show-errors > /dev/null; fi'
    arguments: '--resourceToken \'${resourceToken}\''
  }
  dependsOn: [
    openConfigSvcsForEdits
  ]
}

resource storageAppConfigKvRef 'Microsoft.AppConfiguration/configurationStores/keyValues@2022-05-01' = {
  parent: appConfigSvc
  name: 'App:StorageAccount:ConnectionString'
  properties: {
    value: string({
      uri: '${kv.properties.vaultUri}secrets/${storageSetup.outputs.keyVaultStorageConnStrName}'
    })
    contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
  }
  dependsOn: [
    openConfigSvcsForEdits
  ]
}

var aspNetCoreEnvironment = isProd ? 'Production' : 'Development'

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

      // Set to true to route all outbound app traffic into virtual network (see https://learn.microsoft.com/azure/app-service/overview-vnet-integration#application-routing)
      vnetRouteAllEnabled: false
    }
    httpsOnly: true

    // Enable regional virtual network integration.
    virtualNetworkSubnetId: vnet::webSubnet.id
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
      ASPNETCORE_ENVIRONMENT: aspNetCoreEnvironment
      AZURE_CLIENT_ID: managedIdentity.properties.clientId
      APPLICATIONINSIGHTS_CONNECTION_STRING: webApplicationInsightsResources.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING
      'App:AppConfig:Uri': appConfigSvc.properties.endpoint
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
      // App Insights settings
      // https://docs.microsoft.com/en-us/azure/azure-monitor/app/azure-web-apps-net#application-settings-definitions
      APPINSIGHTS_INSTRUMENTATIONKEY: webApplicationInsightsResources.outputs.APPLICATIONINSIGHTS_INSTRUMENTATION_KEY
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      XDT_MicrosoftApplicationInsights_Mode: 'recommended'
      InstrumentationEngine_EXTENSION_VERSION: '~1'
      XDT_MicrosoftApplicationInsights_BaseExtensions: '~1'
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
    dependsOn: [
      appSettings
    ]
  }
}

resource api 'Microsoft.Web/sites@2021-01-15' = {
  name: 'api-${resourceToken}-web-app'
  location: location
  tags: union(tags, {
      'azd-service-name': 'api'
    })
  properties: {
    serverFarmId: apiAppServicePlan.id
    siteConfig: {
      alwaysOn: true
      ftpsState: 'FtpsOnly'

      // Set to true to route all outbound app traffic into virtual network (see https://learn.microsoft.com/azure/app-service/overview-vnet-integration#application-routing)
      vnetRouteAllEnabled: false
    }
    httpsOnly: true

    // Enable regional virtual network integration.
    virtualNetworkSubnetId: vnet::apiSubnet.id
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
      ASPNETCORE_ENVIRONMENT: aspNetCoreEnvironment
      AZURE_CLIENT_ID: managedIdentity.properties.clientId
      APPLICATIONINSIGHTS_CONNECTION_STRING: webApplicationInsightsResources.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING
      'Api:AppConfig:Uri': appConfigSvc.properties.endpoint
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
      // App Insights settings
      // https://docs.microsoft.com/en-us/azure/azure-monitor/app/azure-web-apps-net#application-settings-definitions
      APPINSIGHTS_INSTRUMENTATIONKEY: webApplicationInsightsResources.outputs.APPLICATIONINSIGHTS_INSTRUMENTATION_KEY
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      XDT_MicrosoftApplicationInsights_Mode: 'recommended'
      InstrumentationEngine_EXTENSION_VERSION: '~1'
      XDT_MicrosoftApplicationInsights_BaseExtensions: '~1'
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
    dependsOn: [
      appSettings
    ]
  }
}

resource appConfigSvc 'Microsoft.AppConfiguration/configurationStores@2022-05-01' = {
  name: '${resourceToken}-appconfig'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
}

var appServicePlanSku = (isProd) ? 'P1v2' : 'B1'

resource webAppServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${resourceToken}-web-plan'
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
  }
  properties: {

  }
  dependsOn: [
    // found that Redis network connectivity was not available if web app is deployed first (until restart)
    // delaying deployment allows us to skip the restart
    redisSetup
  ]
}

resource apiAppServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${resourceToken}-api-plan'
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
  }
  properties: {

  }
  dependsOn: [
    // found that Redis network connectivity was not available if web app is deployed first (until restart)
    // delaying deployment allows us to skip the restart
    redisSetup
  ]
}

resource webAppScaleRule 'Microsoft.Insights/autoscalesettings@2021-05-01-preview' = if (isProd) {
  name: '${resourceToken}-web-plan-autoscale'
  location: location
  tags: tags
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
  tags: tags
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


resource adminVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: 'admin-${resourceToken}-kv' // keyvault name cannot start with a number
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enabledForTemplateDeployment: true
    accessPolicies: [
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

var defaultSqlPassword = 'a${toUpper(uniqueString(subscription().id, resourceToken))}3${toUpper(uniqueString(managedIdentity.properties.principalId, resourceToken))}Q'

resource kvSqlAdministratorPassword 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: adminVault
  name: 'sqlAdministratorPassword'
  properties: {
    // uniqueString produces a 13 character result
    // concatenation of 2 unique strings produces a 26 character password unique to your subscription per environment
    value: defaultSqlPassword
  }
}

var sqlAdministratorLogin = 'sqladmin${resourceToken}'
resource kvSqlAdministratorLogin 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: adminVault
  name: 'sqlAdministratorLogin'
  properties: {
    value: sqlAdministratorLogin
  }
}

module sqlSetup 'azureSqlDatabase.bicep' = {
  name: 'sqlSetup'
  scope: resourceGroup()
  params: {
    devOpsManagedIdentityId: devOpsManagedIdentityId
    isProd: isProd
    location: location
    managedIdentity: {
      name: managedIdentity.name
      id: managedIdentity.id
      properties: {
        clientId: managedIdentity.properties.clientId
        principalId: managedIdentity.properties.principalId
        tenantId: managedIdentity.properties.tenantId
      }
    }
    resourceToken: resourceToken
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorPassword: adminVault.getSecret(kvSqlAdministratorPassword.name)
    tags: tags
  }
  dependsOn: [
    vnet
  ]
}

var privateEndpointNameForRedis = 'privateEndpointForRedis'
module redisSetup 'azureRedisCache.bicep' = {
  name: 'redisSetup'
  scope: resourceGroup()
  params: {
    devOpsManagedIdentityId: devOpsManagedIdentityId
    isProd: isProd
    location: location
    resourceToken: resourceToken
    tags: tags
    privateEndpointNameForRedis: privateEndpointNameForRedis
    privateEndpointVnetName: vnet.name
    privateEndpointSubnetName: privateEndpointSubnetName
  }
}

module storageSetup 'azureStorage.bicep' = {
  name: 'storageSetup'
  scope: resourceGroup()
  params: {
    isProd: isProd
    location: location
    resourceToken: resourceToken
    tags: tags
  }
  dependsOn: [
    vnet
  ]
}

var privateEndpointSubnetName = 'subnetPrivateEndpoints'
var subnetApiAppService = 'subnetApiAppService'
var subnetWebAppService = 'subnetWebAppService'

resource vnet 'Microsoft.Network/virtualNetworks@2020-07-01' = {
  name: 'rc-${resourceToken}-vnet'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: '10.0.0.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: subnetWebAppService
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
      {
        name: subnetApiAppService
        properties: {
          addressPrefix: '10.0.2.0/24'
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

  resource apiSubnet 'subnets' existing = {
    name: subnetApiAppService
  }

  resource webSubnet 'subnets' existing = {
    name: subnetWebAppService
  }
}

resource privateEndpointForSql 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: 'privateEndpointForSql'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateEndpointSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: '${sqlSetup.outputs.sqlServerName}/${sqlSetup.outputs.sqlDatabaseName}'
        properties: {
          privateLinkServiceId: sqlSetup.outputs.sqlServerId
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneNameForSql 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
  tags: tags
  dependsOn: [
    vnet
  ]
}

resource privateDnsZoneNameForSql_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneNameForSql
  name: '${privateDnsZoneNameForSql.name}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource sqlPvtEndpointDnsGroupName 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-07-01' = {
  name: '${privateEndpointForSql.name}/mydnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneNameForSql.id
        }
      }
    ]
  }
}

resource redisPvtEndpointDnsGroupName 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-07-01' = {
  name: '${privateEndpointNameForRedis}/mydnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: redisSetup.outputs.privateDnsZoneId
        }
      }
    ]
  }
}

// private link for Key vault

resource privateDnsZoneNameForKv 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
  dependsOn: [
    vnet
  ]
}

resource privateDnsZoneNameForKv_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneNameForKv
  name: '${privateDnsZoneNameForKv.name}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource pvtEndpointDnsGroupNameForKv 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-07-01' = {
  name: '${privateEndpointForKv.name}/mydnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneNameForKv.id
        }
      }
    ]
  }
}

resource privateEndpointForKv 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: 'privateEndpointForKv'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateEndpointSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: kv.name
        properties: {
          privateLinkServiceId: kv.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// private link for App Config Svc

resource privateDnsZoneNameForAppConfig 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azconfig.io'
  location: 'global'
  tags: tags
  dependsOn: [
    vnet
  ]
}

resource privateDnsZoneNameForAppConfig_link 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneNameForAppConfig
  name: '${privateDnsZoneNameForAppConfig.name}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource pvtEndpointDnsGroupNameForAppConfig 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-07-01' = {
  name: '${privateEndpointForAppConfig.name}/mydnsgroupname'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneNameForAppConfig.id
        }
      }
    ]
  }
}

resource privateEndpointForAppConfig 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: 'privateEndpointForAppConfig'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, privateEndpointSubnetName)
    }
    privateLinkServiceConnections: [
      {
        name: appConfigSvc.name
        properties: {
          privateLinkServiceId: appConfigSvc.id
          groupIds: [
            'configurationStores'
          ]
        }
      }
    ]
  }
}

// app config vars cannot be set without public network access
// the above config settings must depend on this block to ensure
// access is allowed before we try saving the setting
resource openConfigSvcsForEdits 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'openConfigSvcsForEdits'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${devOpsManagedIdentityId}': {}
    }
  }
  properties: {
    forceUpdateTag: uniqueScriptId
    azCliVersion: '2.37.0'
    retentionInterval: 'P1D'
    environmentVariables: [
      {
        name: 'APP_CONFIG_SVC_NAME'
        value: appConfigSvc.name
      }
      {
        name: 'KEY_VAULT_NAME'
        value: kv.name
      }
      {
        name: 'RESOURCE_GROUP'
        secureValue: resourceGroup().name
      }
    ]
    scriptContent: '''
      az appconfig update --name $APP_CONFIG_SVC_NAME --resource-group $RESOURCE_GROUP --enable-public-network true
      az keyvault update --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP  --public-network-access Enabled
      '''
  }
}

resource closeConfigSvcsForEdits 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (isProd) {
  name: 'closeConfigSvcsForEdits'
  location: location
  tags: tags
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${devOpsManagedIdentityId}': {}
    }
  }
  properties: {
    forceUpdateTag: uniqueScriptId
    azCliVersion: '2.37.0'
    retentionInterval: 'P1D'
    environmentVariables: [
      {
        name: 'APP_CONFIG_SVC_NAME'
        value: appConfigSvc.name
      }
      {
        name: 'KEY_VAULT_NAME'
        value: kv.name
      }
      {
        name: 'RESOURCE_GROUP'
        secureValue: resourceGroup().name
      }
    ]
    scriptContent: '''
      az appconfig update --name $APP_CONFIG_SVC_NAME --resource-group $RESOURCE_GROUP --enable-public-network false
      az keyvault update --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP  --public-network-access Disabled
      '''
  }
  // app config vars cannot be set without public network access
  // now that they are set - we block public access for prod
  // and leave public access enabled to support local dev scenarios
  dependsOn:[
    baseApiUrlAppConfigSetting
    sqlConnStrAppConfigSetting
    redisConnAppConfigKvRef
    frontEndClientSecretAppCfg
    storageAppConfigKvRef
  ]
}

output WEB_URI string = web.properties.defaultHostName
output API_URI string = api.properties.defaultHostName
