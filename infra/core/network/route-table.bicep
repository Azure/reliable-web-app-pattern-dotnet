targetScope = 'resourceGroup'

/*
** Route Table
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
** Settings
*/
@description('Optional. Switch to disable BGP route propagation.')
param disableBgpRoutePropagation bool = false

@description('The list of routes to install in the route table')
param routes object[]

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource routeTable 'Microsoft.Network/routeTables@2022-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    routes: routes
    disableBgpRoutePropagation: disableBgpRoutePropagation
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = routeTable.id
output name string = routeTable.name
