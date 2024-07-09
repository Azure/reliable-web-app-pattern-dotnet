targetScope = 'resourceGroup'
metadata description = 'Creates an Azure Cognitive Services instance.'

/*
** Cognitive Services instance
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

import { PrivateEndpointSettings } from '../../types/PrivateEndpointSettings.bicep'


// ========================================================================
// PARAMETERS
// ========================================================================

@description('Name of the cognitive services resource')
param name string

@description('If set, the private endpoint settings for this resource')
param privateEndpointSettings PrivateEndpointSettings?


@description('The Azure region for the resource.')
param location string = resourceGroup().location

/*
** Settings
*/

@description('The tags to associate with this resource.')
param tags object = {}

@description('The custom subdomain name used to access the API. Defaults to the value of the name parameter.')
param customSubDomainName string = name

param disableLocalAuth bool = false

@description('A collection of models that will be deployed while creating the resource. Models must align by availability to azure region')
param deployments array = []

// could potentially also be FormRecognizer/SpeechServices/ComputerVision in future versions
@allowed(['OpenAI'])
param kind string = 'OpenAI'

@description('The IP address of the current system.  This is used to set up the firewall for Key Vault and SQL Server if in development mode.')
param clientIpAddress string

@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'
param sku object = {
  name: 'S0'
}
@allowed([ 'None', 'AzureServices' ])
param bypass string = 'None'

resource account 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
    // Some services do not support bypass in network acls
    // networkAcls: (kind == 'FormRecognizer' || kind == 'ComputerVision' || kind == 'SpeechServices') ? networkAcls : networkAclsWithBypass
    networkAcls: {
      defaultAction: 'Allow'
      ipRules:concat([], empty(clientIpAddress)? [] : [
        {value: clientIpAddress} // allow the clientIpAddress if one was provided
      ])
      bypass: bypass
    }
    disableLocalAuth: disableLocalAuth
  }
  sku: sku
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  parent: account
  name: deployment.name
  properties: {
    model: deployment.model
    raiPolicyName: contains(deployment, 'raiPolicyName') ? deployment.raiPolicyName : null
  }
  sku: contains(deployment, 'sku') ? deployment.sku : {
    name: 'Standard'
    capacity: 20
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
    linkServiceId: account.id
    linkServiceName: account.name
    subnetId: privateEndpointSettings != null ? privateEndpointSettings!.subnetId : ''

    // Settings
    dnsZoneName: 'privatelink.openai.azure.com'
    groupIds: [ 'account' ]
  }
}

output endpoint string = account.properties.endpoint
output id string = account.id
output name string = account.name
output location string = account.location
