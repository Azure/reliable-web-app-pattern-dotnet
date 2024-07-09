targetScope = 'resourceGroup'
metadata description = 'Creates an Azure AI Search instance.'

/*
** Azure AI Search instance
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

import { PrivateEndpointSettings } from '../../types/PrivateEndpointSettings.bicep'


// ========================================================================
// PARAMETERS
// ========================================================================

@description('Name of the AI Searc resource')
param name string

@description('If set, the private endpoint settings for this resource')
param privateEndpointSettings PrivateEndpointSettings?

param location string = resourceGroup().location

param tags object = {}

param sku object = {
  name: 'standard'
}

param authOptions object = {}
param disableLocalAuth bool = false
param encryptionWithCmk object = {
  enforcement: 'Unspecified'
}
@allowed([
  'default'
  'highDensity'
])
param hostingMode string = 'default'
@allowed([
  'enabled'
  'disabled'
])
param publicNetworkAccess string = 'enabled'
param partitionCount int = 1
param replicaCount int = 1
@allowed([
  'disabled'
  'free'
  'standard'
])
param semanticSearch string = 'disabled'

param sharedPrivateLinkStorageAccounts array = []

var searchIdentityProvider = (sku.name == 'free') ? null : {
  type: 'SystemAssigned'
}

resource search 'Microsoft.Search/searchServices@2023-11-01' = {
  name: name
  location: location
  tags: tags
  // The free tier does not support managed identity
  identity: searchIdentityProvider
  properties: {
    authOptions: disableLocalAuth ? null : authOptions
    disableLocalAuth: disableLocalAuth
    encryptionWithCmk: encryptionWithCmk
    hostingMode: hostingMode
    partitionCount: partitionCount
    publicNetworkAccess: publicNetworkAccess
    replicaCount: replicaCount
    semanticSearch: semanticSearch
  }
  sku: sku

  resource sharedPrivateLinkResource 'sharedPrivateLinkResources@2023-11-01' = [for (resourceId, i) in sharedPrivateLinkStorageAccounts: {
    name: 'search-shared-private-link-${i}'
    properties: {
      groupId: 'blob'
      status: 'Approved'
      provisioningState: 'Succeeded'
      requestMessage: 'automatically created by the system'
      privateLinkResourceId: resourceId
    }
  }]
}


module privateEndpoint '../network/private-endpoint.bicep' = if (privateEndpointSettings != null) {
  name: '${name}-private-endpoint'
  scope: resourceGroup(privateEndpointSettings != null ? privateEndpointSettings!.resourceGroupName : resourceGroup().name)
  params: {
    name: privateEndpointSettings != null ? privateEndpointSettings!.name : 'pep-${name}'
    location: location
    tags: tags
    dnsRsourceGroupName: privateEndpointSettings == null ? resourceGroup().name : privateEndpointSettings!.dnsResourceGroupName

    // Dependencies
    linkServiceId: search.id
    linkServiceName: search.name
    subnetId: privateEndpointSettings != null ? privateEndpointSettings!.subnetId : ''

    // Settings
    dnsZoneName: 'privatelink.search.windows.net'
    groupIds: [ 'searchService' ]
  }
}


output id string = search.id
output endpoint string = 'https://${name}.search.windows.net/'
output name string = search.name
output principalId string = !empty(searchIdentityProvider) ? search.identity.principalId : ''
