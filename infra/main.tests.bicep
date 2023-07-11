targetScope = 'subscription'

module main 'main.bicep' = {
  name: 'main'
  params: {
    location: 'westeurope'
    secondaryAzureLocation: 'northeurope'
    azureAdApiScopeFrontEnd: ''
    azureAdClientIdForBackEnd: ''
    azureAdClientIdForFrontEnd: ''
    azureAdClientSecretForFrontEnd: ''
    azureAdTenantId: ''
    name: 'main'
    principalId: 'x'
    principalType: 'ServicePrincipal'
    azureSqlPassword: ''
    enableTelemetry: true
  }
}
