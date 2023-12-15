targetScope = 'resourceGroup'

/*
** Network Security Group
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates a floating Network Security Group that can be attached to a
** subnet or network interface.
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

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

@description('The Azure region for the resource.')
param location string

@description('The name of the primary resource')
param name string

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Dependencies
*/
@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/
@description('The list of security rules to attach to this network security group.')
param securityRules object[]

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: securityRules
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: networkSecurityGroup
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: map([ 'NetworkSecurityGroupEvent', 'NetworkSecurityGroupRuleCounter' ], (category) => {
      category: category
      enabled: diagnosticSettings!.enableLogs
    })
    metrics: []
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = networkSecurityGroup.id
output name string = networkSecurityGroup.name

