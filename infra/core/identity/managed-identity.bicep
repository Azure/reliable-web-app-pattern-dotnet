targetScope = 'resourceGroup'

/*
** User-Assigned Managed Identity
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

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = managedIdentity.id
output name string = managedIdentity.name
output principal_id string = managedIdentity.properties.principalId
