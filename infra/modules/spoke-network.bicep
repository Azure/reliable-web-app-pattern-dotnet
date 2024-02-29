targetScope = 'subscription'

/*
** Spoke Network Infrastructure
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** The Spoke Network consists of a virtual network that hosts resources that
** are associated with the web app workload (e.g. private endpoints).
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/DeploymentSettings.bicep
@description('Type that describes the global deployment settings')
type DeploymentSettings = {
  @description('If \'true\', then two regional deployments will be performed.')
  isMultiLocationDeployment: bool
  
  @description('If \'true\', use production SKUs and settings.')
  isProduction: bool

  @description('If \'true\', isolate the workload in a virtual network.')
  isNetworkIsolated: bool
  
  @description('If \'false\', then this is a multi-location deployment for the second location.')
  isPrimaryLocation: bool

  @description('The Azure region to host resources')
  location: string

  @description('The name of the workload.')
  name: string

  @description('The ID of the principal that is being used to deploy resources.')
  principalId: string

  @description('The type of the \'principalId\' property.')
  principalType: 'ServicePrincipal' | 'User'

  @description('The development stage for this application')
  stage: 'dev' | 'prod'

  @description('The common tags that should be used for all created resources')
  tags: object

  @description('The common tags that should be used for all workload resources')
  workloadTags: object
}

// From: infra/types/DiagnosticSettings.bicep
@description('The diagnostic settings for a resource')
type DiagnosticSettings = {
  @description('The number of days to retain log data.')
  logRetentionInDays: int

  @description('The number of days to retain metric data.')
  metricRetentionInDays: int

  @description('If true, enable diagnostic logging.')
  enableLogs: bool

  @description('If true, enable metrics logging.')
  enableMetrics: bool
}

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The resource names for the resources to be created.')
param resourceNames object

/*
** Dependencies
*/
@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

@description('If set, the ID of the table holding the outbound route to the firewall in the hub network')
param firewallInternalIpAddress string = ''

/*
** Settings
*/
@secure()
@minLength(8)
@description('The password for the administrator account on the jump host.')
param administratorPassword string = newGuid()

@minLength(8)
@description('The username for the administrator account on the jump host.')
param administratorUsername string = 'adminuser'

@description('The CIDR block to use for the address prefix of this virtual network.')
param addressPrefix string = '10.0.16.0/20'

@description('If true, create a subnet for Devops resources')
param createDevopsSubnet bool = false

@description('If enabled, a Windows 11 jump host will be deployed.  Ensure you enable the bastion host as well.')
param enableJumpHost bool = false


// ========================================================================
// VARIABLES
// ========================================================================

var enableFirewall = !empty(firewallInternalIpAddress)

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, deploymentSettings.workloadTags)

// The subnet prefixes for the individual subnets inside the virtual network
var subnetPrefixes = [ for i in range(0, 16): cidrSubnet(addressPrefix, 26, i)]

// When creating the virtual network, we need to set up a service delegation for app services.
var appServiceDelegation = [
  {
    name: 'ServiceDelegation'
    properties: {
      serviceName: 'Microsoft.Web/serverFarms'
    }
  }
]

// Network security group rules
var allowHttpsInbound = {
  name: 'Allow-HTTPS-Inbound'
  properties: {
    access: 'Allow'
    description: 'Allow HTTPS inbound traffic'
    destinationAddressPrefix: '*'
    destinationPortRange: '443'
    direction: 'Inbound'
    priority: 100
    protocol: 'Tcp'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
  }
}

var allowSqlInbound = {
  name: 'Allow-SQL-Inbound'
  properties: {
    access: 'Allow'
    description: 'Allow SQL inbound traffic'
    destinationAddressPrefix: '*'
    destinationPortRange: '1433'
    direction: 'Inbound'
    priority: 110
    protocol: 'Tcp'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
  }
}

var denyAllInbound = {
  name: 'Deny-All-Inbound'
  properties: {
    access: 'Deny'
    description: 'Deny all inbound traffic'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
    direction: 'Inbound'
    priority: 1000
    protocol: 'Tcp'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
  }
}

// Sets up the route table when there is one specified.
var routeTableSettings = enableFirewall ? {
  routeTable: { id: routeTable.outputs.id }
} : {}

var devopsSubnet = createDevopsSubnet ? [{
  name: resourceNames.spokeDevopsSubnet
  properties: {
    addressPrefix: subnetPrefixes[6]
    privateEndpointNetworkPolicies: 'Disabled'
  }
}] : []

// ========================================================================
// AZURE MODULES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceNames.spokeResourceGroup
}

module apiInboundNSG '../core/network/network-security-group.bicep' = {
  name: deploymentSettings.isPrimaryLocation ? 'spoke-api-inbound-nsg-0' : 'spoke-api-inbound-nsg-1'
  scope: resourceGroup
  params: {
    name: resourceNames.spokeApiInboundNSG
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    securityRules: [
      allowHttpsInbound
      denyAllInbound
    ]
  }
}

module apiOutboundNSG '../core/network/network-security-group.bicep' = {
  name: deploymentSettings.isPrimaryLocation ? 'spoke-api-outbound-nsg-0' : 'spoke-api-outbound-nsg-1'
  scope: resourceGroup
  params: {
    name: resourceNames.spokeApiOutboundNSG
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    securityRules: [
      denyAllInbound
    ]
  }
}

module privateEndpointNSG '../core/network/network-security-group.bicep' = {
  name: deploymentSettings.isPrimaryLocation ? 'spoke-pep-nsg-0' : 'spoke-pep-nsg-0'
  scope: resourceGroup
  params: {
    name: resourceNames.spokePrivateEndpointNSG
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    securityRules: [
      allowHttpsInbound
      allowSqlInbound
      denyAllInbound
    ]
  }
}

module webInboundNSG '../core/network/network-security-group.bicep' = {
  name: deploymentSettings.isPrimaryLocation ? 'spoke-web-inbound-nsg-0' : 'spoke-web-inbound-nsg-1'
  scope: resourceGroup
  params: {
    name: resourceNames.spokeWebInboundNSG
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    securityRules: [
      allowHttpsInbound
      denyAllInbound
    ]
  }
}

module webOutboundNSG '../core/network/network-security-group.bicep' = {
  name: deploymentSettings.isPrimaryLocation ? 'spoke-web-outbound-nsg-0' : 'spoke-web-outbound-nsg-1'
  scope: resourceGroup
  params: {
    name: resourceNames.spokeWebOutboundNSG
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    diagnosticSettings: diagnosticSettings
    securityRules: [
      denyAllInbound
    ]
  }
}

module virtualNetwork '../core/network/virtual-network.bicep' = {
  name: deploymentSettings.isPrimaryLocation ? 'spoke-virtual-network-0' : 'spoke-virtual-network-1'
  scope: resourceGroup
  params: {
    name: resourceNames.spokeVirtualNetwork
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    addressPrefix: addressPrefix
    diagnosticSettings: diagnosticSettings
    subnets: union([
      {
        name: resourceNames.spokePrivateEndpointSubnet
        properties: {
          addressPrefix: subnetPrefixes[0]
          networkSecurityGroup: { id: privateEndpointNSG.outputs.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: resourceNames.spokeApiInboundSubnet
        properties: {
          addressPrefix: subnetPrefixes[1]
          networkSecurityGroup: { id: apiInboundNSG.outputs.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: resourceNames.spokeApiOutboundSubnet
        properties: union({
          addressPrefix: subnetPrefixes[2]
          delegations: appServiceDelegation
          networkSecurityGroup: { id: apiOutboundNSG.outputs.id }
          privateEndpointNetworkPolicies: 'Enabled'
        }, routeTableSettings)
      }
      {
        name: resourceNames.spokeWebInboundSubnet
        properties: {
          addressPrefix: subnetPrefixes[3]
          networkSecurityGroup: { id: webInboundNSG.outputs.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: resourceNames.spokeWebOutboundSubnet
        properties: union({
          addressPrefix: subnetPrefixes[4]
          delegations: appServiceDelegation
          networkSecurityGroup: { id: webOutboundNSG.outputs.id }
          privateEndpointNetworkPolicies: 'Enabled'
        }, routeTableSettings)
      }], devopsSubnet)
  }
}

module routeTable '../core/network/route-table.bicep' = if (enableFirewall) {
  name: deploymentSettings.isPrimaryLocation ? 'spoke-route-table-0' : 'spoke-route-table-1'
  scope: resourceGroup
  params: {
    name: resourceNames.spokeRouteTable
    location: deploymentSettings.location
    tags: moduleTags

    // Settings
    routes: [
      {
        name: 'defaultEgress'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: firewallInternalIpAddress
          nextHopType: 'VirtualAppliance'
        }
      }
    ]
  }
}

module jumphost '../core/compute/windows-jumphost.bicep' = if (enableJumpHost) {
  name: deploymentSettings.isPrimaryLocation ? 'hub-jumphost-0' : 'hub-jumphost-1'
  scope: resourceGroup
  params: {
    name: resourceNames.hubJumphost
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    subnetId: virtualNetwork.outputs.subnets[resourceNames.spokeDevopsSubnet].id

    // Settings
    administratorPassword: administratorPassword
    administratorUsername: administratorUsername
    diagnosticSettings: diagnosticSettings
    
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
  name: deploymentSettings.isPrimaryLocation ? 'spoke-prvt-0-dns-zone-deploy' : 'spoke-prvt-1-dns-zone-deploy'
  params:{
    createDnsZone: false //we are reusing the existing DNS zone and linking a vnet
    deploymentSettings: deploymentSettings
    hubResourceGroupName: resourceNames.hubResourceGroup
    virtualNetworkLinks: virtualNetworkLinks
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output virtual_network_id string = virtualNetwork.outputs.id
output virtual_network_name string = virtualNetwork.outputs.name
output subnets object = virtualNetwork.outputs.subnets
output jumphost_computer_name string = enableJumpHost ? jumphost.outputs.computer_name : ''
