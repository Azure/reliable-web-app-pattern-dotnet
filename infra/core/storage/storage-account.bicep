targetScope = 'resourceGroup'

/*
** Azure Storage Account
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

// From: infra/types/ApplicationIdentity.bicep
@description('Type describing an application identity.')
type ApplicationIdentity = {
  @description('The ID of the identity')
  principalId: string

  @description('The type of identity - either ServicePrincipal or User')
  principalType: 'ServicePrincipal' | 'User'
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

// From: infra/types/PrivateEndpointSettings.bicep
@description('Type describing the private endpoint settings.')
type PrivateEndpointSettings = {
  @description('The name of the resource group to hold the Private DNS Zone. By default, this uses the same resource group as the resource.')
  dnsResourceGroupName: string
  
  @description('The name of the private endpoint resource.')
  name: string

  @description('The name of the resource group to hold the private endpoint.')
  resourceGroupName: string

  @description('The ID of the subnet to link the private endpoint to.')
  subnetId: string
}

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
** Settings
*/

@description('Required for storage accounts where kind = BlobStorage. The access tier is used for billing.')
@allowed(['Cool', 'Hot', 'Premium' ])
param accessTier string = 'Hot'

@description('Allow or disallow public access to all blobs or containers in the storage account. The default interpretation is true for this property.')
param allowBlobPublicAccess bool = true

@description('Allow or disallow cross AAD tenant object replication. The default interpretation is true for this property.')
param allowCrossTenantReplication bool = true

@description('Indicates whether the storage account permits requests to be authorized with the account access key via Shared Key. If false, then all requests, including shared access signatures, must be authorized with Azure Active Directory (Azure AD). The default value is null, which is equivalent to true.')
param allowSharedKeyAccess bool = true

@description('The list of application identities to be granted contributor access to the application resources.')
param contributorIdentities ApplicationIdentity[] = []

@description('Whether or not public endpoint access is allowed for this server')
param enablePublicNetworkAccess bool = true

@description('Required. Indicates the type of storage account.')
@allowed(['BlobStorage', 'BlockBlobStorage', 'FileStorage', 'Storage', 'StorageV2' ])
param kind string = 'StorageV2'

@description('Set the minimum TLS version to be permitted on requests to storage.')
@allowed(['TLS1_0','TLS1_1','TLS1_2'])
param minimumTlsVersion string = 'TLS1_2'

@description('The list of application identities to be granted owner access to the application resources.')
param ownerIdentities ApplicationIdentity[] = []

@description('If set, the private endpoint settings for this resource')
param privateEndpointSettings PrivateEndpointSettings?

@description('Required. Gets or sets the SKU name.')
param sku object = { name: 'Standard_LRS' }

// ========================================================================
// VARIABLES
// ========================================================================

/* https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles */

// Provides full access to Azure Storage blob containers and data, including assigning POSIX access control.
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'

// Read, write, and delete Azure Storage containers and blobs. To learn which actions are required for a given data operation
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

var defaultToOAuthAuthentication = false
var dnsEndpointType = 'Standard'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  sku: sku
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    allowCrossTenantReplication: allowCrossTenantReplication
    allowSharedKeyAccess: allowSharedKeyAccess
    defaultToOAuthAuthentication: defaultToOAuthAuthentication
    dnsEndpointType: dnsEndpointType
    minimumTlsVersion: minimumTlsVersion
    publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
  }
}

resource grantOwnerAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in ownerIdentities: if (!empty(id.principalId)) {
  name: guid(storageBlobDataOwnerRoleId, id.principalId, storage.id, resourceGroup().name)
  scope: storage
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
    principalId: id.principalId
  }
}]

resource grantContributorAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for id in contributorIdentities: if (!empty(id.principalId)) {
  name: guid(storageBlobDataContributorRoleId, id.principalId, storage.id, resourceGroup().name)
  scope: storage
  properties: {
    principalType: id.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: id.principalId
  }
}]

module privateEndpoint '../network/private-endpoint.bicep' = if (privateEndpointSettings != null) {
  name: '${name}-private-endpoint'
  scope: resourceGroup(privateEndpointSettings != null ? privateEndpointSettings!.resourceGroupName : resourceGroup().name)
  params: {
    name: privateEndpointSettings != null ? privateEndpointSettings!.name : 'pep-${name}'
    location: location
    tags: tags
    dnsRsourceGroupName: privateEndpointSettings == null ? resourceGroup().name : privateEndpointSettings!.dnsResourceGroupName

    // Dependencies
    linkServiceId: storage.id
    linkServiceName: storage.name
    subnetId: privateEndpointSettings != null ? privateEndpointSettings!.subnetId : ''

    // Settings
    dnsZoneName: 'privatelink.blob.${environment().suffixes.storage}'
    groupIds: [ 'blob' ]
  }
}

output name string = storage.name
output primaryEndpoints object = storage.properties.primaryEndpoints
