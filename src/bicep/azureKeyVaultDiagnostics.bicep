@minLength(1)
@description('ResourceId for a log analytics workspace that will collect diagnostic info for Key Vault and Front Door')
param logAnalyticsWorkspaceIdForDiagnostics string

@minLength(1)
@description('Name of a key vault that shuold be monitored')
param keyVaultName string

resource existingKeyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: keyVaultName
}

resource keyVaultDiagnosticSettings  'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: existingKeyVault
  name: 'default'
  properties: {
    workspaceId: logAnalyticsWorkspaceIdForDiagnostics
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
