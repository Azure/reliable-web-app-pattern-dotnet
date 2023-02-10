@minLength(1)
@description('Name for a log analytics workspace that will collect diagnostic info for Key Vault and Front Door')
param logAnalyticsWorkspaceNameForDiagnstics string

@minLength(1)
@description('Name of a key vault that shuold be monitored')
param keyVaultName string

resource logAnalyticsWorkspaceForDiagnostics 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceNameForDiagnstics
}

resource existingKeyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: keyVaultName
}

resource keyVaultDiagnosticSettings  'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: existingKeyVault
  name: 'default'
  properties: {
    workspaceId: logAnalyticsWorkspaceForDiagnostics.id
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
