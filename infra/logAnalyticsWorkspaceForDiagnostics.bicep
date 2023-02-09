@minLength(1)
@description('Name for a log analytics workspace that will collect diagnostic info for Key Vault and Front Door')
param logAnalyticsWorkspaceNameForDiagnstics string

@minLength(1)
@description('Primary location for all resources. Should specify an Azure region. e.g. `eastus2` ')
param location string

@description('An object collection that contains annotations to describe the deployed azure resources to improve operational visibility')
param tags object

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceNameForDiagnstics
  location: location
  tags: tags
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

output logAnalyticsWorkspaceNameForDiagnstics string = logAnalyticsWorkspaceNameForDiagnstics
