@description('Enables the template to choose different SKU by environment')
param isProd bool

@description('The id for the user-assigned managed identity that runs deploymentScripts')
param devOpsManagedIdentityId string

@secure()
@minLength(1)
@description('Specifies a password that will be used to secure the Azure SQL Database')
param azureSqlPassword string

@minLength(1)
@description('Primary location for all resources. Should specify an Azure region. e.g. `eastus2` ')
param location string

@minLength(1)
@description('Primary location for all resources. Should specify an Azure region. e.g. `eastus2` ')
param logAnalyticsWorkspaceNameForDiagnstics string

@minLength(1)
@description('The user running the deployment will be given access to the deployed resources such as Key Vault and App Config svc')
param principalId string

@description('A generated identifier used to create unique resources')
param resourceToken string

// Adding RBAC permissions via the script enables the sample to work around a permission propagation issue outlined in the issue
// https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/138
@minLength(1)
@description('When the deployment is executed by a user we give the principal RBAC access to key vault')
param principalType string

@description('An object collection that contains annotations to describe the deployed azure resources to improve operational visibility')
param tags object

@description('A user-assigned managed identity that is used by the App Service app')
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'web-${resourceToken}-identity'
  location: location
  tags: tags
}

@description('Built in \'Data Reader\' role ID: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles')
var appConfigurationRoleDefinitionId = '516239f1-63e1-4d78-a4de-a74fb236a071'

@description('Grant the \'Data Reader\' role to the user-assigned managed identity, at the scope of the resource group.')
resource appConfigRoleAssignmentForWebApps 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(appConfigurationRoleDefinitionId, appConfigService.id, managedIdentity.name, resourceToken)
  scope: resourceGroup()
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', appConfigurationRoleDefinitionId)
    principalId: managedIdentity.properties.principalId
    description: 'Grant the "Data Reader" role to the user-assigned managed identity so it can access the azure app configuration service.'
  }
}

@description('Grant the \'Data Reader\' role to the principal, at the scope of the resource group.')
resource appConfigRoleAssignmentForPrincipal 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (principalType == 'user') {
  name: guid(appConfigurationRoleDefinitionId, appConfigService.id, principalId, resourceToken)
  scope: resourceGroup()
  properties: {
    principalType: 'User'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', appConfigurationRoleDefinitionId)
    principalId: principalId
    description: 'Grant the "Data Reader" role to the principal identity so it can access the azure app configuration service.'
  }
}

// a key vault name that is shared between KV and Azure App Configuration Service to support Azure AD auth for the web app
var frontEndClientSecretName = 'AzureAd--ClientSecret'

// for non-prod scenarios we allow public network connections for the local dev experience
var keyVaultPublicNetworkAccess = isProd ? 'disabled' : 'enabled'

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: 'rc-${resourceToken}-kv' // keyvault name cannot start with a number
  location: location
  tags: tags
  properties: {
    publicNetworkAccess: keyVaultPublicNetworkAccess
    networkAcls:{
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
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

resource appConfigService 'Microsoft.AppConfiguration/configurationStores@2022-05-01' = {
  name: '${resourceToken}-appconfig'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties:{
    // This network mode supports making the sample easier to get started
    // It uses public network access because the values are set by the Azure Resource Provider
    // by this declarative bicep file. To disable public network access would require
    // access to the vnet and connecting over the private endpoint
    // https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/230
    publicNetworkAccess:'Enabled'
  }

  resource baseApiUrlAppConfigSetting 'keyValues@2022-05-01' = {
    name: 'App:RelecloudApi:BaseUri'
    properties: {
      value: 'https://${api.properties.defaultHostName}'
    }
  }

  resource sqlConnStrAppConfigSetting 'keyValues@2022-05-01' = {
    name: 'App:SqlDatabase:ConnectionString'
    properties: {
      value: 'Server=tcp:${sqlSetup.outputs.sqlServerFqdn},1433;Initial Catalog=${sqlSetup.outputs.sqlCatalogName};Authentication=Active Directory Default'
    }
  }

  resource redisConnAppConfigKvRef 'keyValues@2022-05-01' = {
    name: 'App:RedisCache:ConnectionString'
    properties: {
      value: string({
        uri: '${keyVault.properties.vaultUri}secrets/${redisSetup.outputs.keyVaultRedisConnStrName}'
      })
      contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
    }
  }

  resource frontEndClientSecretAppCfg 'keyValues@2022-05-01' = {
    name: 'AzureAd:ClientSecret'
    properties: {
      value: string({
        uri: '${keyVault.properties.vaultUri}secrets/${frontEndClientSecretName}'
      })
      contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
    }
  }

  resource storageAppConfigKvRef 'keyValues@2022-05-01' = {
    name: 'App:StorageAccount:ConnectionString'
    properties: {
      value: string({
        uri: '${keyVault.properties.vaultUri}secrets/${storageSetup.outputs.keyVaultStorageConnStrName}'
      })
      contentType: 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8'
    }
  }
}

// provides additional diagnostic information from aspNet when deploying non-prod environments
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
      'App:AppConfig:Uri': appConfigService.properties.endpoint
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
      'Api:AppConfig:Uri': appConfigService.properties.endpoint
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

module webServicePlanAutoScale './appSvcAutoScaleSettings.bicep' = {
  name: 'deploy-${webAppServicePlan.name}-scalesettings'
  params: {
    appServicePlanName: webAppServicePlan.name
    location: location
    isProd: isProd
    tags: tags
  }
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

module apiServicePlanAutoScale './appSvcAutoScaleSettings.bicep' = {
  name: 'deploy-${apiAppServicePlan.name}-scalesettings'
  params: {
    appServicePlanName: apiAppServicePlan.name
    location: location
    isProd: isProd
    tags: tags
  }
}

resource webLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: 'web-${resourceToken}-log'
  location: location
  tags: tags
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
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
    sqlAdministratorLogin: 'sqladmin${resourceToken}'
    sqlAdministratorPassword: azureSqlPassword
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
        name: keyVault.name
        properties: {
          privateLinkServiceId: keyVault.id
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
        name: appConfigService.name
        properties: {
          privateLinkServiceId: appConfigService.id
          groupIds: [
            'configurationStores'
          ]
        }
      }
    ]
  }
}

output WEB_URI string = web.properties.defaultHostName
output API_URI string = api.properties.defaultHostName
