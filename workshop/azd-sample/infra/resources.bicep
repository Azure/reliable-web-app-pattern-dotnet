@description('Enables the template to choose different SKU by environment')
param isProd bool

@minLength(1)
@description('Primary location for all resources. Should specify an Azure region. e.g. `eastus2` ')
param location string

@description('A generated identifier used to create unique resources')
param resourceToken string

@description('An object collection that contains annotations to describe the deployed azure resources to improve operational visibility')
param tags object

@description('The name for azd to identify the web app service by')
param webServiceName string

@description('The name of the overall environment')
param environmentName string

resource appConfigService 'Microsoft.AppConfiguration/configurationStores@2022-05-01' = {
  name: 'appconfig-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties:{
    publicNetworkAccess:'Enabled'
  }

  resource baseApiUrlAppConfigSetting 'keyValues@2022-05-01' = {
    name: 'greeting'
    properties: {
      value: 'Hello RWA Workshop at Build!'
    }
  }
}

resource web 'Microsoft.Web/sites@2021-03-01' = {
  name: '${environmentName}-web-${resourceToken}'
  location: location
  tags: union(tags, {
      'azd-service-name': webServiceName
    })
  properties: {
    serverFarmId: webAppServicePlan.id
    siteConfig: {
      alwaysOn: true
      ftpsState: 'Disabled'
    }
    httpsOnly: true
  }
  resource appSettings 'config' = {
    name: 'appsettings'
    properties: {
      // get the app config connection string from appConfigService
      'AzureUrls:AppConfiguration': appConfigService.listKeys().value[0].connectionString
    }
  }
}

var appServicePlanSku = (isProd) ? 'P1v3' : 'B1'

resource webAppServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: '${environmentName}-web-plan-${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
  }
}

output WEB_APP_URL string = web.properties.defaultHostName
