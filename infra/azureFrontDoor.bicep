// this file is included for the sample to make it easy to get started
// for customer scenarios we recommend reusing your Azure Front Door
// as it supports multiple origins, and endpoints for different needs
param tags object

// avoids resource token naming since front door is a global balancer
var globalResourceToken = uniqueString(resourceGroup().id)
var frontDoorEndpointName = 'afd-${globalResourceToken}'

@description('The hostname of the backend. Must be an IP address or FQDN.')
param primaryBackendAddress string

@description('The hostname of the backend. Must be an IP address or FQDN.')
param secondaryBackendAddress string

var frontDoorProfileName = 'fd-${globalResourceToken}'
var frontDoorOriginGroupName = 'MyOriginGroup'
var frontDoorOriginName = 'MyAppServiceOrigin'
var frontDoorRouteName = 'MyRoute'

resource frontDoorProfile 'Microsoft.Cdn/profiles@2021-06-01' = {
  name: frontDoorProfileName
  tags: tags
  location: 'global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2021-06-01' = {
  name: frontDoorEndpointName
  parent: frontDoorProfile
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource frontDoorOriginGroup 'Microsoft.Cdn/profiles/originGroups@2021-06-01' = {
  name: frontDoorOriginGroupName
  parent: frontDoorProfile
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
  }
}

resource frontDoorPrimaryOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = {
  name: '${frontDoorOriginName}1'
  parent: frontDoorOriginGroup
  properties: {
    hostName: primaryBackendAddress
    httpPort: 80
    httpsPort: 443
    originHostHeader: primaryBackendAddress
    priority: 1
    weight: 1000
  }
}

resource frontDoorSecondaryOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2021-06-01' = if (secondaryBackendAddress != 'none') {
  name: '${frontDoorOriginName}2'
  parent: frontDoorOriginGroup
  properties: {
    hostName: secondaryBackendAddress
    httpPort: 80
    httpsPort: 443
    originHostHeader: secondaryBackendAddress
    priority: 2
    weight: 1000
  }
}

resource frontDoorRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2021-06-01' = {
  name: frontDoorRouteName
  parent: frontDoorEndpoint
  dependsOn: [
    // These explicit dependencies are required to ensure that the origin group is not empty when the route is created.
    frontDoorPrimaryOrigin
    frontDoorSecondaryOrigin
  ]
  properties: {
    originGroup: {
      id: frontDoorOriginGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
}

resource frontdoorWebApplicationFirewallPolicy 'Microsoft.Network/frontdoorwebapplicationfirewallpolicies@2020-11-01' = {
  name: 'wafpolicy${globalResourceToken}'
  location: 'Global'
  sku: {
    name: 'Standard_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: 'Enabled'
    }
    customRules: {
      rules: []
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.0'
          ruleSetAction: 'Block'
          ruleGroupOverrides: []
          exclusions: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
          ruleSetAction: 'Block'
          ruleGroupOverrides: []
          exclusions: []
        }
      ]
    }
  }
}

resource profiles_manualryckozesqpn24_name_manualwafpolicy_cfc67469 'Microsoft.Cdn/profiles/securitypolicies@2021-06-01' = {
  parent: frontDoorProfile
  name: 'wafpolicy-${globalResourceToken}'
  properties: {
    parameters: {
      wafPolicy: {
        id: frontdoorWebApplicationFirewallPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
      type: 'WebApplicationFirewall'
    }
  }
}

output WEB_URI string = frontDoorEndpoint.properties.hostName
