targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unqiue hash used in all resources.')
param name string

@minLength(1)
@description('Primary location for all resources. Should specify an Azure region. e.g. `eastus2` ')
param location string

@minLength(1)
@description('Id of the user or app to assign application roles')
param principalId string

@description('Will select production ready SKUs when `true`')
param isProd string = 'false'

@description('Should specify an Azure region, if not set to none, to trigger multiregional deployment. The second region should be different than the `location` . e.g. `westus3`')
param secondaryAzureLocation string

@secure()
@description('Specifies a password that will be used to secure the Azure SQL Database')
param azureSqlPassword string = ''

// Adding RBAC permissions via the script enables the sample to work around a permission propagation issue outlined in the issue
// https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/138
@minLength(1)
@description('When the deployment is executed by a user we give the principal RBAC access to key vault')
param principalType string

var isProdBool = isProd == 'true' ? true : false

var tags = {
  'azd-env-name': name
}

var isMultiLocationDeployment = secondaryAzureLocation == '' ? false : true

var primaryResourceGroupName = '${name}-rg'
var secondaryResourceGroupName = '${name}-secondary-rg'

var primaryResourceToken = toLower(uniqueString(subscription().id, primaryResourceGroupName, location))
var secondaryResourceToken = toLower(uniqueString(subscription().id, secondaryResourceGroupName, secondaryAzureLocation))

module logAnalyticsForDiagnostics 'logAnalyticsWorkspaceForDiagnostics.bicep' = {
  name: 'logAnalyticsForDiagnostics'
  scope: primaryResourceGroup
  params: {
    tags: tags
    location: location
    logAnalyticsWorkspaceNameForDiagnstics: 'diagnostics-${primaryResourceToken}-log'
  }
}

resource primaryResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: primaryResourceGroupName
  location: location
  tags: tags
}

module devOpsIdentitySetup './devOpsIdentitySetup.bicep' = {
  name: 'devOpsIdentitySetup'
  scope: primaryResourceGroup
  params: {
    tags: tags
    location: location
    resourceToken: primaryResourceToken
  }
}

// temporary workaround for multiple resource group bug
// https://github.com/Azure/azure-dev/issues/690
// `azd down` expects to be able to delete this resource because it was listed by the azure deployment output even when it is not deployed
resource secondaryResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: secondaryResourceGroupName
  location: isMultiLocationDeployment ? secondaryAzureLocation : location
  tags: tags
}

module primaryResources './resources.bicep' = {
  name: 'primary-${primaryResourceToken}'
  scope: primaryResourceGroup
  params: {
    azureSqlPassword: azureSqlPassword
    devOpsManagedIdentityId: devOpsIdentitySetup.outputs.devOpsManagedIdentityId
    isProd: isProdBool
    location: location
    principalId: principalId
    principalType: principalType
    resourceToken: primaryResourceToken
    tags: tags
  }
}

module devOpsIdentitySetupSecondary './devOpsIdentitySetup.bicep' = if (isMultiLocationDeployment) {
  name: 'devOpsIdentitySetupSecondary'
  scope: secondaryResourceGroup
  params: {
    tags: tags
    location: location
    resourceToken: secondaryResourceToken
  }
}

module secondaryResources './resources.bicep' = if (isMultiLocationDeployment) {
  name: 'secondary-${primaryResourceToken}'
  scope: secondaryResourceGroup
  params: {
    azureSqlPassword: azureSqlPassword
    // when not deployed, the evaluation of this template must still supply a valid parameter
    devOpsManagedIdentityId: isMultiLocationDeployment ? devOpsIdentitySetupSecondary.outputs.devOpsManagedIdentityId : 'none'
    isProd: isProdBool
    location: secondaryAzureLocation
    principalId: principalId
    principalType: principalType
    resourceToken: secondaryResourceToken
    tags: tags
  }
}

module azureFrontDoor './azureFrontDoor.bicep' = {
  name: 'frontDoor-${primaryResourceToken}'
  scope: primaryResourceGroup
  params: {
    tags: tags
    logAnalyticsWorkspaceNameForDiagnstics: logAnalyticsForDiagnostics.outputs.logAnalyticsWorkspaceNameForDiagnstics
    primaryBackendAddress: primaryResources.outputs.WEB_URI
    secondaryBackendAddress: isMultiLocationDeployment ? secondaryResources.outputs.WEB_URI : 'none'
  }
}

module primaryAppConfigSvcFrontDoorUri 'appConfigSvcKeyValue.bicep' = {
  name: 'primaryKeyValue'
  scope: primaryResourceGroup
  params:{
    appConfigurationServiceName: primaryResources.outputs.APP_CONFIGURATION_SVC_NAME
    frontDoorUri: azureFrontDoor.outputs.HOST_NAME
  }
}

module primaryKeyVaultDiagnostics 'azureKeyVaultDiagnostics.bicep' = {
  name: 'primaryKeyVaultDiagnostics'
  scope: primaryResourceGroup
  params: {
    keyVaultName: primaryResources.outputs.KEY_VAULT_NAME
    logAnalyticsWorkspaceNameForDiagnstics: logAnalyticsForDiagnostics.outputs.logAnalyticsWorkspaceNameForDiagnstics
  }
}

module secondaryAppConfigSvcFrontDoorUri 'appConfigSvcKeyValue.bicep' = if (isMultiLocationDeployment) {
  name: 'secondaryKeyValue'
  scope: secondaryResourceGroup
  params:{
    appConfigurationServiceName: isMultiLocationDeployment ? secondaryResources.outputs.APP_CONFIGURATION_SVC_NAME : 'none'
    frontDoorUri: azureFrontDoor.outputs.HOST_NAME
  }
}

module secondaryKeyVaultDiagnostics 'azureKeyVaultDiagnostics.bicep' = if (isMultiLocationDeployment) {
  name: 'secondaryKeyVaultDiagnostics'
  scope: secondaryResourceGroup
  params: {
    keyVaultName: isMultiLocationDeployment ? secondaryResources.outputs.KEY_VAULT_NAME : 'none'
    logAnalyticsWorkspaceNameForDiagnstics: logAnalyticsForDiagnostics.outputs.logAnalyticsWorkspaceNameForDiagnstics
  }
}

@description('Enable usage and telemetry feedback to Microsoft.')
param enableTelemetry bool = true

var telemetryId = '063f9e42-c824-4573-8a47-5f6112612fe2-${location}'
resource telemetrydeployment 'Microsoft.Resources/deployments@2021-04-01' = if (enableTelemetry) {
  name: telemetryId
  location: location
  properties: {
    mode: 'Incremental'
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
      contentVersion: '1.0.0.0'
      resources: {}
    }
  }
}

output WEB_URI string = 'https://${azureFrontDoor.outputs.HOST_NAME}'
output AZURE_LOCATION string = location

output DEBUG_IS_MULTI_LOCATION_DEPLOYMENT bool = isMultiLocationDeployment
output DEBUG_SECONDARY_AZURE_LOCATION string = secondaryAzureLocation
output DEBUG_IS_PROD bool = isProdBool
