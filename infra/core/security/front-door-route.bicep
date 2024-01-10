/*
** Azure Front Door Route
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

type PrivateLinkSettings = {
  @description('The resource ID of the private endpoint resource')
  privateEndpointResourceId: string?

  @description('The private link resource type')
  linkResourceType: string?

  @description('The Azure region hosting the private link')
  location: string?
}

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The name of the Azure Front Door endpoint to configure.')
param frontDoorEndpointName string

@description('The name of the Azure Front Door profile to configure.')
param frontDoorProfileName string

@description('The HTTP method to use for the health probe')
@allowed([ 'HEAD', 'GET' ])
param healthProbeMethod string = 'HEAD'

@description('The path portion of the URI for the health probe')
param healthProbePath string = '/'

@description('The prefix for the name of the resources to create')
param originPrefix string

@description('The private link settings for the backend service')
param privateLinkSettings PrivateLinkSettings = {}

@description('The route pattern to route to this backend service')
param routePattern string

@description('The host name to use for backend service routing')
param serviceAddress string

@description('A directory path on the origin that AzureFrontDoor can use to retrieve content from, e.g. contoso.cloudapp.net/originpath')
param originPath string

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

var isPrivateLinkOrigin = contains(privateLinkSettings, 'privateEndpointResourceId')

var privateLinkOriginDetails = isPrivateLinkOrigin ? {
  privateLink: {
    id: privateLinkSettings.privateEndpointResourceId ?? ''
  }
  groupId: privateLinkSettings.linkResourceType ?? ''
  privateLinkLocation: privateLinkSettings.location ?? ''
  requestMessage: 'Please approve the private link request'
} : null

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource profile 'Microsoft.Cdn/profiles@2021-06-01' existing = {
  name: frontDoorProfileName
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' existing = {
  name: frontDoorEndpointName
  parent: profile
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: '${originPrefix}-origin-group'
  parent: profile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: healthProbePath
      probeRequestType: healthProbeMethod
      probeProtocol: 'Https'
      probeIntervalInSeconds: 120
    }
  }
}

resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  name: '${originPrefix}-origin'
  parent: originGroup
  properties: {
    hostName: serviceAddress
    httpPort: 80
    httpsPort: 443
    originHostHeader: serviceAddress
    priority: 1
    sharedPrivateLinkResource: isPrivateLinkOrigin ? privateLinkOriginDetails : null
    weight: 1000
  }
}

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: '${originPrefix}-route'
  parent: endpoint
  dependsOn: [
    origin
  ]
  properties: {
    originGroup: {
      id: originGroup.id
    }
    supportedProtocols: [ 'Http', 'Https' ]
    patternsToMatch: [ routePattern ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    originPath: originPath
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output endpoint string = 'https://${endpoint.properties.hostName}${routePattern}'
output uri string = 'https://${endpoint.properties.hostName}'
