targetScope = 'resourceGroup'

/*
** Private Endpoint
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates a private endpoint for a resource.
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
@description('The ID of the linked service')
param linkServiceId string

@description('The name of the linked service')
param linkServiceName string

@description('The ID of the subnet to host the private endpoint')
param subnetId string

/*
** Settings
*/

@description('The resourceGroup where the Private DNS zone is located')
param dnsRsourceGroupName string

@description('The DNS zone name that will be used for registering the private link.')
param dnsZoneName string

@description('The list of group IDs to redirect through the private endpoint.')
param groupIds string[]

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: { 
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: linkServiceName
        properties: {
          privateLinkServiceId: linkServiceId
          groupIds: groupIds
        }
      }
    ]
  }
}

resource dnsGroupName 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = {
  name: 'mydnsgroupname'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: dnsRsourceGroupName == '' ? resourceId('Microsoft.Network/privateDnsZones', dnsZoneName) : resourceId(dnsRsourceGroupName, 'Microsoft.Network/privateDnsZones', dnsZoneName)
        }
      }
    ]
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = privateEndpoint.id
output name string = privateEndpoint.name
