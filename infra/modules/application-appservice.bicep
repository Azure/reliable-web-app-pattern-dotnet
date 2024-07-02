targetScope = 'resourceGroup'

/*
** An App Service running on a App Service Plan
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
*/

import { PrivateEndpointSettings } from '../types/PrivateEndpointSettings.bicep'
import { DiagnosticSettings } from '../types/DiagnosticSettings.bicep'
import { DeploymentSettings } from '../types/DeploymentSettings.bicep'

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The deployment settings to use for this deployment.')
param deploymentSettings DeploymentSettings

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Dependencies
*/
@description('The name of the App Configuration store to configure for configuration.')
param appConfigurationName string

@description('The ID of the Application Insights instance to use for logging.')
param applicationInsightsId string

@description('The name of the App Service Plan to use for compute resources.')
param appServicePlanName string

@description('The managed identity name to use as the identity of the App Service.')
param managedIdentityName string

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

/*
** Settings
*/
@description('The name of the App Service to create.')
param appServiceName string

@description('If using VNET integration, the ID of the subnet for outbound traffic.')
param outboundSubnetId string = ''

@description('If using network isolation, the settings for the private endpoint.')
param privateEndpointSettings PrivateEndpointSettings?

@description('If not blank, restrict the App Service to only allow traffic from the specified front door.')
param restrictToFrontDoor string = ''

@description('The service prefix to use.')
param servicePrefix string

@description('If true, use an existing App Service Plan')
param useExistingAppServicePlan bool = false

// ========================================================================
// VARIABLES
// ========================================================================

// Get the name and resource group for the Application Insights instance.
// var applicationInsightsName = split('/', applicationInsightsId)[8]
// var applicationInsightsRG = split('/', applicationInsightsId)[4]

var applicationInsights = reference(applicationInsightsId, '2020-02-02')

// ========================================================================
// AZURE RESOURCES
// ========================================================================


resource appConfigurationStore 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: appConfigurationName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

module appServicePlan '../core/hosting/app-service-plan.bicep' = if (!useExistingAppServicePlan) {
  name: '${servicePrefix}-app-service-plan'
  params: {
    name: appServicePlanName
    location: deploymentSettings.location
    tags: tags
    
    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId

    // Settings
    autoScaleSettings: deploymentSettings.isProduction ? { maxCapacity: 10, minCapacity: 3 } : null
    diagnosticSettings: diagnosticSettings
    sku: deploymentSettings.isProduction ? 'P1v3' : 'B1'
    zoneRedundant: deploymentSettings.isProduction
  }
}

module appService '../core/hosting/app-service.bicep' = {
  name: '${servicePrefix}-app-service'
  params: {
    name: appServiceName
    location: deploymentSettings.location
    tags: tags

    // Dependencies
    appServicePlanName: useExistingAppServicePlan ? appServicePlanName : appServicePlan.outputs.name
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    managedIdentityId: managedIdentity.id
    outboundSubnetId: outboundSubnetId

    // Settings
    appSettings: {
      SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
      ASPNETCORE_ENVIRONMENT: deploymentSettings.isProduction ? 'Production' : 'Development'

      // Application Insights
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      XDT_MicrosoftApplicationInsights_Mode: 'recommended'
      InstrumentationEngine_EXTENSION_VERSION: '~1'
      XDT_MicrosoftApplicationInsights_BaseExtensions: '~1'
      APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.ConnectionString
      APPLICATIONINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.InstrumentationKey

      // Identity for DefaultAzureCredential connections
      AZURE_CLIENT_ID: managedIdentity.properties.clientId

      // App Configuration
      'App:AppConfig:Uri': appConfigurationStore.properties.endpoint
    }
    diagnosticSettings: diagnosticSettings
    enablePublicNetworkAccess: !deploymentSettings.isNetworkIsolated
    ipSecurityRestrictions: !empty(restrictToFrontDoor) ? [
      {
        tag: 'ServiceTag'
        ipAddress: 'AzureFrontDoor.Backend'
        action: 'Allow'
        priority: 100
        headers: {
          'x-azure-fdid': [ restrictToFrontDoor ]
        }
        name: 'Allow traffic from Front Door'
      }
    ] : []
    privateEndpointSettings: privateEndpointSettings
    servicePrefix: servicePrefix
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output app_service_id string = appService.outputs.id
output app_service_name string = appService.outputs.name
output app_service_hostname string = appService.outputs.hostname
output app_service_uri string = appService.outputs.uri

