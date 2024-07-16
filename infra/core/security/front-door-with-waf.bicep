/*
** Azure Front Door
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates an Azure Front Door resource with a Web application Firewall
*/

import { DiagnosticSettings } from '../../types/DiagnosticSettings.bicep'

// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

// =====================================================================================================================
//     USER-DEFINED TYPES
// =====================================================================================================================

type WAFRuleSet = {
  @description('The name of the rule set')
  name: string

  @description('The version of the rule set')
  version: string
}

type CustomRule = {
  @description('The name of the custom rule')
  name: string

  @description('The priority of the custom rule')
  priority: int

  @description('The state of the custom rule')
  enabledState: string

  @description('The rule type "MatchRule" or "RateLimitRule".')
  ruleType: string

  @description('The action to take when the rule is triggered')
  action: string

  @description('Number of allowed requests per client within the time window.')
  rateLimitThreshold: int

  @description('Time window for resetting the rate limit count. Default is 1 minute.')
  rateLimitDurationInMinutes: int

  @description('The match conditions for the rule')
  matchConditions: {
    @description('The match variable')
    matchVariable: string

    @description('The operator to use for the match')
    operator: string

    @description('Describes if the result of this condition should be negated.')
    negateCondition: bool

    @description('The values to match against')
    matchValue: string[]
  }[]
}

type CustomRuleList = {
  @description('A list of custom rules to apply')
  rules: CustomRule[]
}

// =====================================================================================================================
//     PARAMETERS
// =====================================================================================================================

@description('The diagnostic settings to use for this resource')
param diagnosticSettings DiagnosticSettings

@description('The tags to associate with the resource')
param tags object

/*
** Resource names to create
*/
@description('The name of the Azure Front Door endpoint to create')
param frontDoorEndpointName string

@description('The name of the Azure Front Door profile to create')
param frontDoorProfileName string

@description('The name of the Web Application Firewall to create')
param webApplicationFirewallName string

/*
** Dependencies
*/
@description('The Log Analytics Workspace to send diagnostic and audit data to')
param logAnalyticsWorkspaceId string

/*
** Service settings
*/
@description('A list of managed rule sets to enable')
param managedRules WAFRuleSet[]

@description('A list of custom rules to apply')
param customRules CustomRuleList?

@allowed([ 'Premium', 'Standard' ])
@description('The pricing plan to use for the Azure Front Door and Web Application Firewall')
param sku string

// =====================================================================================================================
//     CALCULATED VARIABLES
// =====================================================================================================================

// For a list of all categories that this resource supports, see: https://learn.microsoft.com/azure/azure-monitor/essentials/resource-logs-categories
var logCategories = [
  'FrontDoorAccessLog'
  'FrontDoorWebApplicationFirewallLog'
] 

// Convert the managed rule sets list into the object form required by the web application firewall
var managedRuleSets = map(managedRules, rule => {
  ruleSetType: rule.name
  ruleSetVersion: rule.version
  ruleSetAction: 'Block'
  ruleGroupOverrides: []
  exclusions: []
})

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

resource frontDoorProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: frontDoorProfileName
  location: 'global'
  tags: tags
  sku: {
    name: '${sku}_AzureFrontDoor'
  }
}

resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  name: frontDoorEndpointName
  parent: frontDoorProfile
  location: 'global'
  tags: tags
  properties: {
    enabledState: 'Enabled'
  }
}

resource wafPolicy 'Microsoft.Network/frontdoorwebapplicationfirewallpolicies@2024-02-01' = {
  name: webApplicationFirewallName
  location: 'global'
  tags: tags
  sku: {
    name: '${sku}_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: 'Enabled'
    }
    customRules: customRules
    managedRules: {
      managedRuleSets: sku == 'Premium' ? managedRuleSets : []
    }
  }
}

resource wafPolicyLink 'Microsoft.Cdn/profiles/securityPolicies@2023-05-01' = {
  name: '${webApplicationFirewallName}-link'
  parent: frontDoorProfile
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            { id: frontDoorEndpoint.id }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${frontDoorProfileName}-diagnostics'
  scope: frontDoorProfile
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: map(logCategories, (category) => {
      category: category
      enabled: diagnosticSettings!.enableLogs
    })
    metrics: [
      {
        category: 'AllMetrics'
        enabled: diagnosticSettings!.enableMetrics
      }
    ]
  }
}

// =====================================================================================================================
//     AZURE RESOURCES
// =====================================================================================================================

output endpoint_name string = frontDoorEndpoint.name
output profile_name string = frontDoorProfile.name
output waf_name string = wafPolicy.name

output front_door_id string = frontDoorProfile.properties.frontDoorId
output hostname string = frontDoorEndpoint.properties.hostName
output uri string = 'https://${frontDoorEndpoint.properties.hostName}'
