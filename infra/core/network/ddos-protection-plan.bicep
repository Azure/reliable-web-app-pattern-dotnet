targetScope = 'resourceGroup'

/*
** DDoS Protection Plan
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Create a DDoS Protection Plan.
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

resource ddosProtectionPlan 'Microsoft.Network/ddosProtectionPlans@2022-11-01' = {
  location: location
  name: name
  tags: tags
  properties: {

  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = ddosProtectionPlan.id
output name string = ddosProtectionPlan.name
