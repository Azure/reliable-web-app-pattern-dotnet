targetScope = 'resourceGroup'

/*
** Azure Storage Account
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

// From: infra/types/DiagnosticSettings.bicep
@description('The diagnostic settings for a resource')
type DiagnosticSettings = {
  @description('The number of days to retain log data.')
  logRetentionInDays: int

  @description('The number of days to retain metric data.')
  metricRetentionInDays: int

  @description('If true, enable diagnostic logging.')
  enableLogs: bool

  @description('If true, enable metrics logging.')
  enableMetrics: bool
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The name of the primary resource')
param name string

@description('A collection of objects with each object describing the container name and access level')
param containers array = []

/*
** Dependencies
*/
@description('The name of the storage account.')
param storageAccountName string

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/

@description('The blob service properties for blob soft delete.')
param deleteRetentionPolicy object = {}

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = if (!empty(containers)) {
  parent: storage
  name: 'default'
  properties: {
    deleteRetentionPolicy: deleteRetentionPolicy
  }

  resource container 'containers' = [for container in containers: {
    name: container.name
    properties: {
      publicAccess: contains(container, 'publicAccess') ? container.publicAccess : 'None'
    }
  }]
}


resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: blobServices
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: map([ 'StorageDelete', 'StorageRead', 'StorageWrite' ], (category) => {
      category: category
      enabled: diagnosticSettings!.enableLogs
    })
    metrics: [
      {
        category: 'AllMetrics'
        enabled: diagnosticSettings!.enableMetrics
      }
    ]
  }
}
