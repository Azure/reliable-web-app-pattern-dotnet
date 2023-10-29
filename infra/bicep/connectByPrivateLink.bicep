@minLength(1)
@description('Name of the private endpoint that will be created for this connection')
param name string

@minLength(1)
@description('Primary location for all resources. Should specify an Azure region. e.g. `eastus2` ')
param location string

@minLength(1)
@description('The resourceId of an existing Azure subnet that will be used to create a private endpoint connection')
param subnetResourceId string

@minLength(1)
@description('The resourceId of an existing Azure private DNS that will provide the routing for this private endpoint')
param privateDnsZoneId string

@minLength(1)
@description('The resourceId of an existing Azure resource that will be accessed by the private endpoint connection')
param serviceResourceId string

@description('The type of Azure resource that will be networked as a private endpoint such as `configurationStores` or `vault`')
param serviceGroupIds array 

@description('An object collection that contains annotations to describe the deployed azure resources to improve operational visibility')
param tags object

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          privateLinkServiceId: serviceResourceId
          groupIds: serviceGroupIds
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-07-01' = {
  name: privateEndpoint.name
  parent: privateEndpoint

  properties: {
    privateDnsZoneConfigs: [
      {
        name: name
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

