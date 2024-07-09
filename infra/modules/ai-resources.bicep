targetScope = 'subscription'

/*
** AI Infrastructure
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

import { DeploymentSettings } from '../types/DeploymentSettings.bicep'
import { DiagnosticSettings } from '../types/DiagnosticSettings.bicep'
import { PrivateEndpointSettings } from '../types/PrivateEndpointSettings.bicep'

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The resource names for the resources to be created.')
param resourceNames object

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('If true, use a common App Service Plan.  If false, use a separate App Service Plan per App Service.')
param useCommonAppServicePlan bool

@description('The model version of ChatGpt to deploy. Must align with version supported by region.')
param chatGptDeploymentVersion string = ''

@description('The model version of text-embedding-3 to deploy. Must align with version supported by region.')
param embeddingDeploymentVersion string = ''

/*
** Dependencies
*/

@description('The list of subnets that are used for linking into the virtual network if using network isolation.')
param subnets object = {}

@description('When deploying a hub, the private endpoints will need this parameter to specify the resource group that holds the Private DNS zones')
param dnsResourceGroupName string = ''

@description('The managed identity name to use as the identity of the App Service.')
param managedIdentityName string

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/

@allowed([
  'disabled'
  'free'
  'standard'
])
param searchServiceSemanticRankerLevel string = 'standard'

@description('The service prefix to use.')
param servicePrefix string

@description('The IP address of the current system.  This is used to set up the firewall for Key Vault and SQL Server if in development mode.')
param clientIpAddress string = ''

@allowed([ 'None', 'AzureServices' ])
@description('If allowedIp is set, whether azure services are allowed to bypass the storage and AI services firewall.')
param bypass string = 'AzureServices'

@description('The pricing and capacity SKU for the Cognitive Services deployment')
param openAiSkuName string = 'S0'

@allowed([ 'free', 'basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2' ])
param searchServiceSkuName string = 'standard'

// ========================================================================
// VARIABLES
// ========================================================================

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, deploymentSettings.workloadTags)

var isAzureOpenAiHost = true
var deployAzureOpenAi = true

var chatGpt = {
  modelName: 'gpt-4o'
  deploymentName: 'chat'
  deploymentVersion: !empty(chatGptDeploymentVersion) ? chatGptDeploymentVersion : '2024-05-13'
  deploymentCapacity: 10
}

var embedding = {
  modelName: 'text-embedding-3-large'
  deploymentName: 'embedding'
  deploymentCapacity: 120
  deploymentVersion: !empty(embeddingDeploymentVersion) ? embeddingDeploymentVersion : '1'
  // dimensions: 3072
}

var openAiDeployments = [
  {
    name: chatGpt.deploymentName
    model: {
      format: 'OpenAI'
      name: chatGpt.modelName
      version: chatGpt.deploymentVersion
    }
    sku: {
      name: 'GlobalStandard' //found that the SKU was 'GlobalStandard' instead of 'Standard' for Azure region uksouth, need further research in how tightly to control this param '
      capacity: chatGpt.deploymentCapacity
    }
  }
  {
    name: embedding.deploymentName
    model: {
      format: 'OpenAI'
      name: embedding.modelName
      version: embedding.deploymentVersion
    }
    sku: {
      name: 'Standard'
      capacity: embedding.deploymentCapacity
    }
  }
]

var actualSearchServiceSemanticRankerLevel = (searchServiceSkuName == 'free') ? 'disabled' : searchServiceSemanticRankerLevel

// ========================================================================
// EXISTING RESOURCES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceNames.resourceGroup
}


resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: resourceGroup
  name: managedIdentityName
}

// ========================================================================
// NEW RESOURCES
// ========================================================================

module openAi '../core/ai/cognitiveservices.bicep' = if (isAzureOpenAiHost && deployAzureOpenAi) {
  name: 'openai-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.appCognitiveServices // '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: resourceGroup.location
    tags: moduleTags
    publicNetworkAccess: deploymentSettings.isNetworkIsolated ? 'Disabled' : 'Enabled'
    bypass: bypass // defaults to alow AzureServices
    sku: {
      name: openAiSkuName
    }
    clientIpAddress: clientIpAddress
    deployments: openAiDeployments
    disableLocalAuth: true
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.cogServicesPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id
    } : null
  }
}

var cognitiveServicesOpenAIUser = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource role 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup.id, deploymentSettings.principalId, cognitiveServicesOpenAIUser)
  properties: {
    principalId: deploymentSettings.principalId
    principalType: deploymentSettings.principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUser)
  }
}


// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan '../core/hosting/app-service-plan.bicep' = {
  name: '${servicePrefix}-app-plan-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.pyAppServicePlan //'${abbrs.webServerFarms}${resourceToken}'
    location: resourceGroup.location
    tags: moduleTags
    serverType: 'Linux'

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    
    sku: deploymentSettings.isProduction ? 'P1v3' : 'B1'
    zoneRedundant: deploymentSettings.isProduction
  }
}


module appService '../core/hosting/app-service.bicep' = {
  name: '${servicePrefix}-app-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.pyAppService
    location: resourceGroup.location
    tags: moduleTags

    // Dependencies
    appServicePlanName: useCommonAppServicePlan ? resourceNames.commonAppServicePlan : appServicePlan.outputs.name
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    managedIdentityId: managedIdentity.id
    outboundSubnetId: deploymentSettings.isNetworkIsolated ? subnets[resourceNames.spokeWebOutboundSubnet].id : '' // same as .NET API

    // Settings
    appSettings: {
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
      ASPNETCORE_ENVIRONMENT: deploymentSettings.isProduction ? 'Production' : 'Development'

      // Application Insights
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      XDT_MicrosoftApplicationInsights_Mode: 'recommended'
      InstrumentationEngine_EXTENSION_VERSION: '~1'
      XDT_MicrosoftApplicationInsights_BaseExtensions: '~1'
      //APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.ConnectionString
      //APPLICATIONINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.InstrumentationKey

      // Identity for DefaultAzureCredential connections
      // AZURE_CLIENT_ID: managedIdentity.properties.clientId

      // App Configuration
      // 'App:AppConfig:Uri': appConfigurationStore.properties.endpoint
    }
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.webAppPyPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokeWebInboundSubnet].id
    } : null
    servicePrefix: servicePrefix
  }
}

// =====================================================================================================================
//     AZURE AI Search
// =====================================================================================================================

module searchService '../core/search/search-services.bicep' = {
  name: 'search-service-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    name: resourceNames.searchService
    location: resourceGroup.location
    tags: moduleTags
    disableLocalAuth: true
    sku: {
      name: searchServiceSkuName
    }
    semanticSearch: actualSearchServiceSemanticRankerLevel
    publicNetworkAccess: deploymentSettings.isNetworkIsolated ?  'disabled' : 'enabled'
    sharedPrivateLinkStorageAccounts: [] // does not link to storage accounts
    
    privateEndpointSettings: deploymentSettings.isNetworkIsolated ? {
      dnsResourceGroupName: dnsResourceGroupName
      name: resourceNames.searchPrivateEndpoint
      resourceGroupName: resourceNames.spokeResourceGroup
      subnetId: subnets[resourceNames.spokePrivateEndpointSubnet].id
    } : null
  }
}

module searchDiagnostics '../core/search/search-diagnostics.bicep' = {
  name: 'search-diagnostics-${deploymentSettings.resourceToken}'
  scope: resourceGroup
  params: {
    searchServiceName: searchService.outputs.name
    workspaceId: logAnalyticsWorkspaceId // there may be an option to monitor with App Insights to explore
  }
}

