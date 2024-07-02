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

import { DiagnosticSettings } from '../types/DiagnosticSettings.bicep'
import { DeploymentSettings } from '../types/DeploymentSettings.bicep'

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The diagnostic settings to use for this deployment.')
param diagnosticSettings DiagnosticSettings

@description('The resource names for the resources to be created.')
param resourceNames object

/*
** Dependencies
*/
@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/

@description('If enabled, an Ubuntu jump box will be deployed.  Ensure you enable the bastion host as well.')
param enableJumpBox bool = false

@description('The CIDR block to use for the address prefix of this virtual network.')
param addressPrefix string = '10.0.0.0/20'

@description('If enabled, a Bastion Host will be deployed with a public IP address.')
param enableBastionHost bool = false

@description('If enabled, DDoS Protection will be enabled on the virtual network')
param enableDDoSProtection bool = true

@description('If enabled, an Azure Firewall will be deployed with a public IP address.')
param enableFirewall bool = true

@description('The address spaces allowed to connect through the firewall.  By default, we allow all RFC1918 address spaces')
param internalAddressSpace string[] = [ '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16' ]

@description('If true, create a subnet for Devops resources')
param createDevopsSubnet bool = false

// ========================================================================
// VARIABLES
// ========================================================================

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, {
  WorkloadName: 'NetworkHub'
  OpsCommitment: 'Platform operations'
  ServiceClass: deploymentSettings.isProduction ? 'Gold' : 'Dev'
})

// The subnet prefixes for the individual subnets inside the virtual network
var subnetPrefixes = [ for i in range(0, 16): cidrSubnet(addressPrefix, 26, i)]

// The individual subnet definitions.
var bastionHostSubnetDefinition = {
  name: resourceNames.hubSubnetBastionHost
  properties: {
    addressPrefix: subnetPrefixes[2]
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

var firewallSubnetDefinition = {
  name: resourceNames.hubSubnetFirewall
  properties: {
    addressPrefix: subnetPrefixes[1]
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

var privateEndpointSubnet = {
  name: resourceNames.hubSubnetPrivateEndpoint
  properties: {
    addressPrefix: subnetPrefixes[0]
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

var devopsSubnet = {
  name: resourceNames.spokeDevopsSubnet
  properties: {
    addressPrefix: subnetPrefixes[6]
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

var subnets = union(
  [privateEndpointSubnet],
  enableBastionHost ? [bastionHostSubnetDefinition] : [],
  enableFirewall ? [firewallSubnetDefinition] : [],
  createDevopsSubnet ? [devopsSubnet] : []
)

// Some helpers for the firewall rules
var allowTraffic = { type: 'allow' }
var httpProtocol  = { port: '80', protocolType: 'HTTP' }
var httpsProtocol = { port: '443', protocolType: 'HTTPS' }
var azureFqdns = loadJsonContent('./azure-fqdns.jsonc')

// The firewall application rules
var applicationRuleCollections = [
  {
    name: 'Azure-Monitor'
    properties: {
      action: allowTraffic
      priority: 201
      rules: [
        {
          name: 'allow-azure-monitor'
          protocols: [ httpsProtocol ]
          sourceAddresses: internalAddressSpace
          targetFqdns: azureFqdns.azureMonitor
        }
      ]
    }
  }
  {
    name: 'Core-Dependencies'
    properties: {
      action: allowTraffic
      priority: 200
      rules: [
        {
          name: 'allow-core-apis'
          protocols: [ httpsProtocol ]
          sourceAddresses: internalAddressSpace
          targetFqdns: azureFqdns.coreServices
        }
        {
          name: 'allow-developer-services'
          protocols: [ httpsProtocol ]
          sourceAddresses: internalAddressSpace
          targetFqdns: azureFqdns.developerServices
        }
        {
          name: 'allow-certificate-dependencies'
          protocols: [ httpProtocol, httpsProtocol ]
          sourceAddresses: internalAddressSpace
          targetFqdns: azureFqdns.certificateServices
        }
      ]
    }
  }
]

// The subnet prefixes for the individual subnets inside the virtual network

var networkRuleCollections = [
  {
    name: 'Windows-VM-Connectivity-Requirements'
    properties: {
      action: {
        type: 'allow'
      }
      priority: 202
      rules: [
        {
          destinationAddresses: [
            '20.118.99.224'
            '40.83.235.53'
            '23.102.135.246'
            '51.4.143.248'
            '23.97.0.13'
            '52.126.105.2'
          ]
          destinationPorts: [
            '*'
          ]
          name: 'allow-kms-activation'
          protocols: [
            'Any'
          ]
          sourceAddresses: [ subnetPrefixes[6] ]
        }
        {
          destinationAddresses: [
            '*'
          ]
          destinationPorts: [                
            '123'
            '12000'
          ]
          name: 'allow-ntp'
          protocols: [
            'Any'
          ]
          sourceAddresses: [ subnetPrefixes[6] ]
        }
      ]
    }
  }]
// Our firewall does not use NAT rule collections, but you can set them up here.
var natRuleCollections = []

// Budget amounts
//  All values are calculated in dollars (rounded to nearest dollar) in the South Central US region.
var budgetCategories = deploymentSettings.isProduction ? {
  ddosProtectionPlan: 0         /* Includes protection for 100 public IP addresses */
  azureMonitor: 87              /* Estimate 1GiB/day Analytics, 1GiB/day Basic Logs  */
  applicationInsights: 152      /* Estimate 5GiB/day Application Insights */
  keyVault: 1                   /* Minimal usage - < 100 operations per month */
  virtualNetwork: 0             /* Virtual networks are free - peering included in spoke */
  firewall: 290                 /* Basic plan, 100GiB processed */
  bastionHost: 212              /* Standard plan */
  jumpbox: 85                  /* Standard_B2ms, S10 managed disk, minimal bandwidth usage */
} : {
  ddosProtectionPlan: 0         /* Includes protection for 100 public IP addresses */
  azureMonitor: 69              /* Estimate 1GiB/day Analytics + Basic Logs  */
  applicationInsights: 187      /* Estimate 1GiB/day Application Insights */
  keyVault: 1                   /* Minimal usage - < 100 operations per month */
  virtualNetwork: 0             /* Virtual networks are free - peering included in spoke */
  firewall: 290                 /* Standard plan, 100GiB processed */
  bastionHost: 139              /* Basic plan */
  jumpbox: 85                  /* Standard_B2ms, S10 managed disk, minimal bandwidth usage */
}
var budgetAmount = reduce(map(items(budgetCategories), (obj) => obj.value), 0, (total, amount) => total + amount)

// ========================================================================
// AZURE MODULES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceNames.hubResourceGroup
}

module ddosProtectionPlan '../core/network/ddos-protection-plan.bicep' = if (enableDDoSProtection) {
  name: 'hub-ddos-protection-plan-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.hubDDoSProtectionPlan
    location: deploymentSettings.location
    tags: moduleTags
  }
}

module virtualNetwork '../core/network/virtual-network.bicep' = {
  name: 'hub-virtual-network-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.hubVirtualNetwork
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    ddosProtectionPlanId: enableDDoSProtection ? ddosProtectionPlan.outputs.id : ''
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    addressPrefix: addressPrefix
    diagnosticSettings: diagnosticSettings
    subnets: subnets
  }
}

module firewall '../core/network/firewall.bicep' = if (enableFirewall) {
  name: 'hub-firewall-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.hubFirewall
    location: deploymentSettings.location
    tags: moduleTags
    
    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    subnetId: virtualNetwork.outputs.subnets[resourceNames.hubSubnetFirewall].id

    // Settings
    diagnosticSettings: diagnosticSettings
    publicIpAddressName: resourceNames.hubFirewallPublicIpAddress
    sku: 'Standard'
    threatIntelMode: 'Deny'
    zoneRedundant: deploymentSettings.isProduction

    // Firewall rules
    applicationRuleCollections: applicationRuleCollections
    natRuleCollections: natRuleCollections
    networkRuleCollections: networkRuleCollections
  }
}


module jumpbox '../core/compute/ubuntu-jumpbox.bicep' = if (enableJumpBox) {
  name: 'hub-jumpbox-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.hubJumpbox
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    subnetId: virtualNetwork.outputs.subnets[resourceNames.spokeDevopsSubnet].id

    // users
    users: [ deploymentSettings.principalId ]

    // Settings
    diagnosticSettings: diagnosticSettings
  }
}


module bastionHost '../core/network/bastion-host.bicep' = if (enableBastionHost) {
  name: 'hub-bastion-host-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.hubBastionHost
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    subnetId: virtualNetwork.outputs.subnets[resourceNames.hubSubnetBastionHost].id

    // Settings
    diagnosticSettings: diagnosticSettings
    publicIpAddressName: resourceNames.hubBastionPublicIpAddress
    sku: deploymentSettings.isProduction ? 'Standard' : 'Basic'
    zoneRedundant: deploymentSettings.isProduction
  }
}

/*
  The vault will always be deployed because it stores Microsoft Entra app registration details.
  The dynamic part of this feature is whether or not the Vault is located in the Hub (yes, when Network Isolated)
  or if it is located in the Workload resource group (yes, when Network Isolation is not enabled).
 */
module sharedKeyVault '../core/security/key-vault.bicep' = {
  name: 'shared-key-vault-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.keyVault
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: true
    ownerIdentities: [
      { principalId: deploymentSettings.principalId, principalType: deploymentSettings.principalType }
    ]
    privateEndpointSettings: {
      dnsResourceGroupName: resourceGroup.name
      name: resourceNames.keyVaultPrivateEndpoint
      resourceGroupName: resourceGroup.name
      subnetId: virtualNetwork.outputs.subnets[privateEndpointSubnet.name].id
    }
  }
}

module hubBudget '../core/cost-management/budget.bicep' = {
  name: 'hub-budget-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.hubBudget
    amount: budgetAmount
    contactEmails: [
      deploymentSettings.tags['azd-owner-email']
    ]
    resourceGroups: [
      resourceGroup.name
    ]
  }
}

var virtualNetworkLinks = [
  {
    vnetName: virtualNetwork.outputs.name
    vnetId: virtualNetwork.outputs.id
    registrationEnabled: false
  }
]

module privateDnsZones './private-dns-zones.bicep' = {
  name: 'hub-private-dns-zone-deploy-${deploymentSettings.resourceToken}'
  params:{
    deploymentSettings: deploymentSettings
    hubResourceGroupName: resourceGroup.name
    virtualNetworkLinks: virtualNetworkLinks
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output bastion_name string = enableBastionHost ? bastionHost.outputs.name : ''
output bastion_hostname string = enableBastionHost ? bastionHost.outputs.hostname : ''
output firewall_hostname string = enableFirewall ? firewall.outputs.hostname : ''
output firewall_ip_address string = enableFirewall ? firewall.outputs.internal_ip_address : ''
output virtual_network_id string = virtualNetwork.outputs.id
output virtual_network_name string = virtualNetwork.outputs.name
output key_vault_name string = enableJumpBox ? sharedKeyVault.outputs.name : ''
output jumpbox_computer_name string = enableJumpBox ? jumpbox.outputs.computer_name : ''
output jumpbox_resource_id string = enableJumpBox ? jumpbox.outputs.id : ''
