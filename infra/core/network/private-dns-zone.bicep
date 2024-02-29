targetScope = 'resourceGroup'

/*
** Private DNS Zone
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates a private DNS zone (mostly used for private endpoints) and links
** it to the specified virtual network.
*/

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The name of the primary resource')
param name string

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Dependencies
*/
@description('Array of custom objects describing vNet links of the DNS zone. Each object should contain vnetName, vnetId, registrationEnabled')
param virtualNetworkLinks array = []

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: name
  location: 'global'
  tags: tags
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [ for vnet in virtualNetworkLinks: {
  parent: privateDnsZone
  name:  '${vnet.vnetName}-link'
  location: 'global'
  properties: {
    registrationEnabled: vnet.registrationEnabled
    virtualNetwork: {
      id: vnet.vnetId
    }
  }
}]

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = privateDnsZone.id
output name string = privateDnsZone.name

