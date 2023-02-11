
param name string
param location string
param subnetResourceId string
param privateDnsZoneId string
param serviceResourceId string
param serviceGroupIds array 

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

