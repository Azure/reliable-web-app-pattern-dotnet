@description('Name of the App Configuration Service where the App Service loads configuration')
param appConfigurationServiceName string

@description('A host name for the Azure Front Door that protects the front end web app')
param frontDoorUri string

resource appConfigurationService 'Microsoft.AppConfiguration/configurationStores@2022-05-01' existing = {
  name: appConfigurationServiceName
  
  resource frontDoorRedirectUri 'keyValues@2022-05-01' = {
    name: 'App:FrontDoorUri'
    properties: {
      value: frontDoorUri
    }
  }
}
