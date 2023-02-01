@minLength(1)
@description('Primary location for all resources. Should specify an Azure region. e.g. `eastus2` ')
param location string

@minLength(1)
@description('A generated identifier used to create unique resources')
param resourceToken string

@description('An object collection that contains annotations to describe the deployed azure resources to improve operational visibility')
param tags object

@description('Enables the template to choose different SKU by environment')
param isProd bool

var storageSku = isProd ? 'Standard_ZRS' : 'Standard_LRS'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: '${resourceToken}storage' //storage account name cannot contain character '-'
  tags: tags
  location: location
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'

  resource blobServices 'blobServices' = {
    name:'default'
    resource container 'containers' = {
      name: 'tickets'
    }
  }
}

resource existingKeyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: 'rc-${resourceToken}-kv' // keyvault name cannot start with a number
  scope: resourceGroup()

  resource kvSecretStorageAcct 'secrets@2021-11-01-preview' = {
    name: 'App--StorageAccount--ConnectionString'
    properties: {
      value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
    }
  }
}

output keyVaultStorageConnStrName string = kvSecretStorageAcct.name
