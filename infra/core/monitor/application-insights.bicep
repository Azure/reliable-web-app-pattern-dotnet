targetScope = 'resourceGroup'

/*
** Application Insights
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates an Application Insights resource linked to the provided Log
** Analytics Workspace.
*/

// ========================================================================
// PARAMETERS
// ========================================================================

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
@allowed([ 'web', 'ios', 'other', 'store', 'java', 'phone' ])
@description('The kind of application being monitored.')
param kind string = 'web'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    Application_Type: kind == 'web' ? 'web' : 'other'
    WorkspaceResourceId: logAnalyticsWorkspaceId
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = applicationInsights.id
output name string = applicationInsights.name
