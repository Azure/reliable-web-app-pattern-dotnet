targetScope = 'resourceGroup'

/*
** Log Analytics Workspace
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
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
@allowed([ 'PerGB2018', 'PerNode', 'Premium', 'Standalone', 'Standard' ])
@description('The name of the pricing SKU to use.')
param sku string = 'PerGB2018'

@minValue(0)
@description('The workspace daily quota for ingestion.  Use 0 for unlimited.')
param dailyQuotaInGB int = 0

// ========================================================================
// VARIABLES
// ========================================================================

var skuProperties = {
  sku: {
    name: sku
  }
}
var quotaProperties = dailyQuotaInGB > 0 ? { dailyQuotaGb: dailyQuotaInGB } : {}

var retentionProperties = {
  retentionInDays: 30
}

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: union(skuProperties, quotaProperties, retentionProperties)
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = logAnalyticsWorkspace.id
output name string = logAnalyticsWorkspace.name
