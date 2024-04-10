targetScope = 'resourceGroup'

/*
** Peer two virtual networks together.
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The name of the primary resource')
param name string

/*
** Dependencies
*/
@description('The name of the local virtual network.')
param virtualNetworkName string = ''

@description('The ID of the remote virtual network.')
param remoteVirtualNetworkId string = ''

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: virtualNetworkName

  resource peer 'virtualNetworkPeerings' = {
    name: name
    properties: {
      allowVirtualNetworkAccess: true
      allowGatewayTransit: false
      allowForwardedTraffic: false
      useRemoteGateways: false
      remoteVirtualNetwork: {
        id: remoteVirtualNetworkId
      }
    }
  }
}

