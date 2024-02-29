targetScope = 'subscription'

/*
** Private DNS Zones
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** The Hub Network contains these Private DNS Zones that provide dynamic
** DNS registration for private endpoints in all virtual networks
** associated with this deployment by virtualNetworkLinks.
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

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The list of private DNS zones to create in this virtual network.')
param privateDnsZones array = [
  'privatelink.vaultcore.azure.net'
  'privatelink${az.environment().suffixes.sqlServerHostname}'
  'privatelink.azurewebsites.net'
  'privatelink.redis.cache.windows.net'
  'privatelink.azconfig.io'
  'privatelink.blob.${environment().suffixes.storage}'
]

@description('The hub resource group name.')
param hubResourceGroupName string

@description('Specifies if DNS zone will be created, or if we are attaching to an existing one')
param createDnsZone bool = true

@description('Array of custom objects describing vNet links of the DNS zone. Each object should contain vnetName, vnetId, registrationEnabled')
param virtualNetworkLinks array = []

// ========================================================================
// VARIABLES
// ========================================================================

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, {
  WorkloadName: 'NetworkHub'
  OpsCommitment: 'Platform operations'
  ServiceClass: deploymentSettings.isProduction ? 'Gold' : 'Dev'
})

// ========================================================================
// AZURE Resources
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: hubResourceGroupName
}

module createNewDnsZones '../core/network/private-dns-zone.bicep' = [ for dnsZoneName in createDnsZone ? privateDnsZones : []: {
  name: 'create-new-dns-zone-${dnsZoneName}'
  scope: resourceGroup
  params: {
    name: dnsZoneName
    tags: moduleTags
    virtualNetworkLinks: virtualNetworkLinks
  }
}]

module updateVnetLinkForDnsZones '../core/network/private-dns-zone-link.bicep' = [ for dnsZoneName in !createDnsZone ? privateDnsZones : []: {
  name: createDnsZone ? 'hub-vnet-link-for-dns-${dnsZoneName}' : deploymentSettings.isPrimaryLocation ? 'spk-0-vnet-link-for-dns-${dnsZoneName}' : 'spk-1-link-for-dns-${dnsZoneName}'
  scope: resourceGroup
  params: {
    name: dnsZoneName
    virtualNetworkLinks: virtualNetworkLinks
  }
}]

output dns_resource_group_name string = resourceGroup.name
