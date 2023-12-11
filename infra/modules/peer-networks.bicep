targetScope = 'subscription'

/*
** Hub Network Infrastructure
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** The Hub Network consists of a virtual network that hosts resources that
** are generally associated with a hub.
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

@description('A type to describe a virtual network')
type VirtualNetworkDefinition = {
  @description('The name of the virtual network')
  name: string

  @description('The name of the resource group that contains the virtual network')
  resourceGroupName: string
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The network definition for the hub network')
param hubNetwork VirtualNetworkDefinition

@description('The network definition of the spoke network')
param spokeNetwork VirtualNetworkDefinition

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2020-06-01' existing = {
  name: hubNetwork.name
  scope: resourceGroup(hubNetwork.resourceGroupName)
}

resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2020-06-01' existing = {
  name: spokeNetwork.name
  scope: resourceGroup(spokeNetwork.resourceGroupName)
}

module peerSpokeToHub '../core/network/peer-virtual-network.bicep' = {
  name: 'peer-spoke-to-hub-network'
  scope: resourceGroup(spokeNetwork.resourceGroupName)
  params: {
    name: 'peerTo-${hubVirtualNetwork.name}'
    virtualNetworkName: spokeVirtualNetwork.name
    remoteVirtualNetworkId: hubVirtualNetwork.id
  }
}

module peerHubToSpoke '../core/network/peer-virtual-network.bicep' = {
  name: 'peer-hub-to-spoke-network'
  scope: resourceGroup(hubNetwork.resourceGroupName)
  params: {
    name: 'peerTo-${spokeVirtualNetwork.name}'
    virtualNetworkName: hubVirtualNetwork.name
    remoteVirtualNetworkId: spokeVirtualNetwork.id
  }
}
