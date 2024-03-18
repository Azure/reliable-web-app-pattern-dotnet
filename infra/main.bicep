targetScope = 'subscription'

// ========================================================================
//
//  Relecloud Scenario of the Reliable Web Application (RWA)
//  Infrastructure description
//  Copyright (C) 2023 Microsoft, Inc.
//
// ========================================================================

/*
** Parameters that are provided by Azure Developer CLI.
**
** If you are running this with bicep, use the main.parameters.json
** and overrides to generate these.
*/


@minLength(3)
@maxLength(18)
@description('The environment name - a unique string that is used to identify THIS deployment.')
param environmentName string

@minLength(3)
@description('The name of the Azure region that will be used for the deployment.')
param location string

@minLength(3)
@description('The email address of the owner of the workload.')
param ownerEmail string

@minLength(3)
@description('The name of the owner of the workload.')
param ownerName string

@description('The ID of the running user or service principal.  This will be set as the owner when needed.')
param principalId string = ''

@allowed([ 'ServicePrincipal', 'User' ])
@description('The type of the principal specified in \'principalId\'')
param principalType string = 'ServicePrincipal'

/*
** Passwords - specify these!
*/
@secure()
@minLength(8)
@description('The password for the SQL administrator account. This will be used for the jump host, SQL server, and anywhere else a password is needed for creating a resource.')
param databasePassword string

@secure()
@minLength(12)
@description('The password for the jump host administrator account.')
param jumphostAdministratorPassword string


@minLength(8)
@description('The username for the administrator account.  This will be used for the jump host, SQL server, and anywhere else a password is needed for creating a resource.')
param administratorUsername string = 'azureadmin'

/*
** Parameters that make changes to the deployment based on requirements.  They mostly have
** "reasonable" defaults such that a developer can just run "azd up" and get a working dev
** system.
*/

// Settings for setting up a build agent for Azure DevOps
@description('The URL of the Azure DevOps organization.  If this and the adoToken is provided, then an Azure DevOps build agent will be deployed.')
param adoOrganizationUrl string = ''

@description('The access token for the Azure DevOps organization.  If this and the adoOrganizationUrl is provided, then an Azure DevOps build agent will be deployed.')
param adoToken string = ''

// Settings for setting up a build agent for GitHub Actions
@description('The URL of the GitHub repository.  If this and the githubToken is provided, then a GitHub Actions build agent will be deployed.')
param githubRepositoryUrl string = ''

@description('The personal access token for the GitHub repository.  If this and the githubRepositoryUrl is provided, then a GitHub Actions build agent will be deployed.')
param githubToken string = ''

// The IP address for the current system.  This is used to set up the firewall
// for Key Vault and SQL Server if in development mode.
@description('The IP address of the current system.  This is used to set up the firewall for Key Vault and SQL Server if in development mode.')
param clientIpAddress string = ''

// A differentiator for the environment.  This is used in CI/CD testing to ensure
// that each environment is unique.
@description('A differentiator for the environment.  Set this to a build number or date to ensure that the resource groups and resources are unique.')
param differentiator string = 'none'

// Environment type - dev or prod; affects sizing and what else is deployed alongside.
@allowed([ 'dev', 'prod' ])
@description('The set of pricing SKUs to choose for resources.  \'dev\' uses cheaper SKUs by avoiding features that are unnecessary for writing code.')
param environmentType string = 'dev'

// Deploy Hub Resources; if auto, then
//  - environmentType == dev && networkIsolation == true => true
@allowed([ 'auto', 'false', 'true' ])
@description('Deploy hub resources.  Normally, the hub resources are not deployed since the app developer wouldn\'t have access, but we also need to be able to deploy a complete solution')
param deployHubNetwork string = 'auto'

// Network isolation - determines if the app is deployed in a VNET or not.
//  if environmentType == prod => true
//  if environmentType == dev => false
@allowed([ 'auto', 'false', 'true' ])
@description('Deploy the application in network isolation mode.  \'auto\' will deploy in isolation only if deploying to production.')
param networkIsolation string = 'auto'

// Secondary Azure location - provides the name of the 2nd Azure region. Blank by default to represent a single region deployment.
@description('Should specify an Azure region. If not set to empty string then deploy to single region, else trigger multiregional deployment. The second region should be different than the `location`. e.g. `westus3`')
param azureSecondaryLocation string = ''

// Common App Service Plan - determines if a common app service plan should be deployed.
//  auto = yes in dev, no in prod.
@allowed([ 'auto', 'false', 'true' ])
@description('Should we deploy a common app service plan, used by both the API and WEB app services?  \'auto\' will deploy a common app service plan in dev, but separate plans in prod.')
param useCommonAppServicePlan string = 'auto'

// ========================================================================
// VARIABLES
// ========================================================================

var prefix = '${environmentName}-${environmentType}'

// Boolean to indicate the various values for the deployment settings
var isMultiLocationDeployment = azureSecondaryLocation == '' ? false : true
var isProduction = environmentType == 'prod'
var isNetworkIsolated = networkIsolation == 'true' || (networkIsolation == 'auto' && isProduction)
var willDeployHubNetwork = isNetworkIsolated && (deployHubNetwork == 'true' || (deployHubNetwork == 'auto' && isProduction))
var willDeployCommonAppServicePlan = useCommonAppServicePlan == 'true' || (useCommonAppServicePlan == 'auto' && !isProduction)

// A unique token that is used as a differentiator for all resources.  All resources within the
// same deployment will have the same token.
var primaryResourceToken = uniqueString(subscription().id, environmentName, environmentType, location, differentiator)
var secondaryResourceToken = uniqueString(subscription().id, environmentName, environmentType, azureSecondaryLocation, differentiator)

var defaultDeploymentSettings = {
  isMultiLocationDeployment: isMultiLocationDeployment
  isProduction: isProduction
  isNetworkIsolated: isNetworkIsolated
  isPrimaryLocation: true
  location: location
  name: environmentName
  principalId: principalId
  principalType: principalType
  resourceToken: primaryResourceToken
  stage: environmentType
  tags: {
    'azd-env-name': environmentName
    'azd-env-type': environmentType
    'azd-owner-email': ownerEmail
    'azd-owner-name': ownerName
    ResourceToken: primaryResourceToken
  }
  workloadTags: {
    WorkloadIdentifier: environmentName
    WorkloadName: environmentName
    Environment: environmentType
    OwnerName: ownerEmail
    ServiceClass: isProduction ? 'Silver' : 'Dev'
    OpsCommitment: 'Workload operations'
  }
}

var primaryNamingDeployment = defaultDeploymentSettings
var secondaryNamingDeployment = union(defaultDeploymentSettings, {
  isPrimaryLocation: false
  location: azureSecondaryLocation
  resourceToken: secondaryResourceToken
  tags: {
    ResourceToken: secondaryResourceToken
  }
})

var primaryDeployment = {
  workloadTags: {
    HubGroupName: isNetworkIsolated ? naming.outputs.resourceNames.hubResourceGroup : naming.outputs.resourceNames.resourceGroup
    IsPrimaryLocation: 'true'
    PrimaryLocation: location
    SecondaryLocation: azureSecondaryLocation
  }
}

var primaryDeploymentSettings = union(defaultDeploymentSettings, primaryDeployment)

var secondDeployment = {
  location: azureSecondaryLocation
  isPrimaryLocation: false
  resourceToken: secondaryResourceToken
  tags: {
    ResourceToken: secondaryResourceToken
  }
  workloadTags: {
    HubGroupName: isNetworkIsolated ? naming.outputs.resourceNames.hubResourceGroup : ''
    IsPrimaryLocation: 'false'
    PrimaryLocation: location
    SecondaryLocation: azureSecondaryLocation
  }
}

// a copy of the deploymentSettings that is aware these details describe a second deployment
var secondaryDeploymentSettings = union(defaultDeploymentSettings, secondDeployment)

var diagnosticSettings = {
  logRetentionInDays: isProduction ? 30 : 3
  metricRetentionInDays: isProduction ? 7 : 3
  enableLogs: true
  enableMetrics: true
}

var installBuildAgent = isNetworkIsolated && ((!empty(adoOrganizationUrl) && !empty(adoToken)) || (!empty(githubRepositoryUrl) && !empty(githubToken)))

var spokeAddressPrefixPrimary = '10.0.16.0/20'
var spokeAddressPrefixSecondary = '10.0.32.0/20'

// ========================================================================
// BICEP MODULES
// ========================================================================

/*
** Every single resource can have a naming override.  Overrides should be placed
** into the 'naming.overrides.jsonc' file.  The output of this module drives the
** naming of all resources.
*/
module naming './modules/naming.bicep' = {
  name: '${prefix}-naming'
  params: {
    deploymentSettings: primaryNamingDeployment
    differentiator: differentiator != 'none' ? differentiator : ''
    overrides: loadJsonContent('./naming.overrides.jsonc')
    primaryLocation: location
  }
}

module naming2 './modules/naming.bicep' = {
  name: '${prefix}-naming2'
  params: {
    deploymentSettings: secondaryNamingDeployment
    differentiator: differentiator != 'none' ? '${differentiator}2' : '2'
    overrides: loadJsonContent('./naming.overrides.jsonc')
    primaryLocation: location
  }
}

/*
** Workload resources are organized into one of three resource groups:
**
**  hubResourceGroup      - contains the hub network resources
**  spokeResourceGroup    - contains the spoke network resources
**  applicationResourceGroup - contains the application resources 
** 
** Not all of the resource groups are necessarily available - it
** depends on the settings.
*/
module resourceGroups './modules/resource-groups.bicep' = {
  name: '${prefix}-resource-groups'
  params: {
    deploymentSettings: primaryDeploymentSettings
    resourceNames: naming.outputs.resourceNames

    // Settings
    deployHubNetwork: willDeployHubNetwork
  }
}

module resourceGroups2 './modules/resource-groups.bicep' = if (isMultiLocationDeployment) {
  name: '${prefix}-resource-groups2'
  params: {
    deploymentSettings: secondaryDeploymentSettings
    resourceNames: naming2.outputs.resourceNames

    // Settings
    deployHubNetwork: willDeployHubNetwork
  }
}

/*
** Azure Monitor Resources
**
** Azure Monitor resources (Log Analytics Workspace and Application Insights) are
** homed in the hub network when it's available, and the application resource group
** when it's not available.
*/
module azureMonitor './modules/azure-monitor.bicep' = {
  name: '${prefix}-azure-monitor'
  params: {
    deploymentSettings: primaryDeploymentSettings
    resourceNames: naming.outputs.resourceNames
    resourceGroupName: willDeployHubNetwork ? resourceGroups.outputs.hub_resource_group_name : resourceGroups.outputs.application_resource_group_name
  }
}

/*
** Create the hub network, if requested. 
**
** The hub network consists of the following resources
**
**  The hub virtual network with subnets for Bastion Hosts and Firewall
**  The bastion host
**  The firewall
**  A route table that is used within the spoke to reach the firewall
**
** We also set up a budget with cost alerting for the hub network (separate
** from the application budget)
*/
module hubNetwork './modules/hub-network.bicep' = if (willDeployHubNetwork) {
  name: '${prefix}-hub-network'
  params: {
    deploymentSettings: primaryDeploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: naming.outputs.resourceNames

    // Dependencies
    logAnalyticsWorkspaceId: azureMonitor.outputs.log_analytics_workspace_id

    // Settings
    administratorPassword: jumphostAdministratorPassword
    administratorUsername: administratorUsername
    createDevopsSubnet: true
    enableBastionHost: true
    // DDoS protection is recommended for Production deployments
    // however, for this sample we disable this feature because DDoS should be configured to protect multiple subscriptions, deployments, and resources
    // learn more at https://learn.microsoft.com/azure/ddos-protection/ddos-protection-overview
    enableDDoSProtection: false // primaryDeploymentSettings.isProduction
    enableFirewall: true
    enableJumpHost: true
  }
  dependsOn: [
    resourceGroups
  ]
}

/*
** The hub network MAY have created an Azure Monitor workspace.  If it did, we don't need
** to do it again.  If not, we'll create one in the application resource group
*/


/*
** The spoke network is the network that the application resources are deployed into.
*/
module spokeNetwork './modules/spoke-network.bicep' = if (isNetworkIsolated) {
  name: '${prefix}-spoke-network'
  params: {
    deploymentSettings: primaryDeploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: naming.outputs.resourceNames

    // Dependencies
    logAnalyticsWorkspaceId: azureMonitor.outputs.log_analytics_workspace_id
    firewallInternalIpAddress: willDeployHubNetwork ? hubNetwork.outputs.firewall_ip_address : ''

    // Settings
    addressPrefix: spokeAddressPrefixPrimary
  }
  dependsOn: [
    resourceGroups
  ]
}

module spokeNetwork2 './modules/spoke-network.bicep' = if (isNetworkIsolated && isMultiLocationDeployment) {
  name: '${prefix}-spoke-network2'
  params: {
    deploymentSettings: secondaryDeploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: naming2.outputs.resourceNames

    // Dependencies
    logAnalyticsWorkspaceId: azureMonitor.outputs.log_analytics_workspace_id
    firewallInternalIpAddress: willDeployHubNetwork ? hubNetwork.outputs.firewall_ip_address : ''

    // Settings
    addressPrefix: spokeAddressPrefixSecondary
  }
  dependsOn: [
    resourceGroups2
  ]
}

/*
** Now that the networking resources have been created, we need to peer the networks.  This is
** only done if the hub network was created in this deployment.  If the hub network was not
** deployed, then a manual peering process needs to be done.
*/
module peerHubAndPrimarySpokeVirtualNetworks './modules/peer-networks.bicep' = if (willDeployHubNetwork && isNetworkIsolated) {
  name: '${prefix}-peer-hub-primary-networks'
  params: {
    hubNetwork: {
      name: willDeployHubNetwork ? hubNetwork.outputs.virtual_network_name : ''
      resourceGroupName: naming.outputs.resourceNames.hubResourceGroup
    }
    spokeNetwork: {
      name: isNetworkIsolated ? spokeNetwork.outputs.virtual_network_name : ''
      resourceGroupName: naming.outputs.resourceNames.spokeResourceGroup
    }
  }
}

/* peer the hub and spoke for secondary region if it was deployed */
module peerHubAndSecondarySpokeVirtualNetworks './modules/peer-networks.bicep' = if (willDeployHubNetwork && isNetworkIsolated && isMultiLocationDeployment) {
  name: '${prefix}-peer-hub-secondary-networks'
  params: {
    hubNetwork: {
      name: isMultiLocationDeployment ? hubNetwork.outputs.virtual_network_name : ''
      resourceGroupName: naming.outputs.resourceNames.hubResourceGroup
    }
    spokeNetwork: {
      name: isMultiLocationDeployment ? spokeNetwork2.outputs.virtual_network_name : ''
      resourceGroupName: isMultiLocationDeployment ? naming2.outputs.resourceNames.spokeResourceGroup : ''
    }
  }
}

/*
** Create the application resources.
*/

module frontdoor './modules/shared-frontdoor.bicep' = {
  name: '${prefix}-frontdoor'
  params: {
    deploymentSettings: primaryDeploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: naming.outputs.resourceNames

    // Dependencies
    logAnalyticsWorkspaceId: azureMonitor.outputs.log_analytics_workspace_id
  }
}

module application './modules/application-resources.bicep' = {
  name: '${prefix}-application'
  params: {
    deploymentSettings: primaryDeploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: naming.outputs.resourceNames

    // Dependencies
    applicationInsightsId: azureMonitor.outputs.application_insights_id
    logAnalyticsWorkspaceId: azureMonitor.outputs.log_analytics_workspace_id
    dnsResourceGroupName: willDeployHubNetwork ? resourceGroups.outputs.hub_resource_group_name : ''
    subnets: isNetworkIsolated ? spokeNetwork.outputs.subnets : {}
    frontDoorSettings: frontdoor.outputs.settings

    // Settings
    administratorUsername: administratorUsername
    databasePassword: databasePassword
    clientIpAddress: clientIpAddress
    useCommonAppServicePlan: willDeployCommonAppServicePlan
  }
  dependsOn: [
    resourceGroups
    spokeNetwork
  ]
}

module application2 './modules/application-resources.bicep' =  if (isMultiLocationDeployment) {
  name: '${prefix}-application2'
  params: {
    deploymentSettings: secondaryDeploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: naming2.outputs.resourceNames

    // Dependencies
    applicationInsightsId: azureMonitor.outputs.application_insights_id
    logAnalyticsWorkspaceId: azureMonitor.outputs.log_analytics_workspace_id
    dnsResourceGroupName: willDeployHubNetwork ? resourceGroups.outputs.hub_resource_group_name : ''
    subnets: isNetworkIsolated && isMultiLocationDeployment? spokeNetwork2.outputs.subnets : {}
    frontDoorSettings: frontdoor.outputs.settings

    // Settings
    administratorUsername: administratorUsername
    databasePassword: databasePassword
    clientIpAddress: clientIpAddress
    useCommonAppServicePlan: willDeployCommonAppServicePlan
  }
  dependsOn: [
    resourceGroups2
    spokeNetwork2
  ]
}

/*
** Runs for all configurations (NotIsolated, Isolated, and MultiLocation)
*/
module applicationPostConfiguration './modules/application-post-config.bicep' = {
  name: '${prefix}-application-postconfig'
  params: {
    deploymentSettings: primaryDeploymentSettings
    administratorPassword: jumphostAdministratorPassword
    administratorUsername: administratorUsername
    databasePassword: databasePassword
    keyVaultName: isNetworkIsolated? hubNetwork.outputs.key_vault_name : application.outputs.key_vault_name
    kvResourceGroupName: isNetworkIsolated? resourceGroups.outputs.hub_resource_group_name : resourceGroups.outputs.application_resource_group_name
    readerIdentities: union(application.outputs.service_managed_identities, defaultDeploymentSettings.isMultiLocationDeployment ? application2.outputs.service_managed_identities : [])
    redisCacheNamePrimary: application.outputs.redis_cache_name
    redisCacheNameSecondary: isMultiLocationDeployment ? application2.outputs.redis_cache_name : application.outputs.redis_cache_name
    resourceNames: naming.outputs.resourceNames
    applicationResourceGroupNamePrimary: resourceGroups.outputs.application_resource_group_name
    applicationResourceGroupNameSecondary: isMultiLocationDeployment ? resourceGroups2.outputs.application_resource_group_name : ''
  }
}

/*
** Create a build agent (only if network isolated and the relevant information has been provided)
*/
module buildAgent './modules/build-agent.bicep' = if (installBuildAgent) {
  name: '${prefix}-build-agent'
  params: {
    deploymentSettings: primaryDeploymentSettings
    diagnosticSettings: diagnosticSettings
    resourceNames: naming.outputs.resourceNames

    // Dependencies
    logAnalyticsWorkspaceId: azureMonitor.outputs.log_analytics_workspace_id
    managedIdentityId: application.outputs.owner_managed_identity_id
    subnets: isNetworkIsolated ? spokeNetwork.outputs.subnets : {}

    // Settings
    administratorPassword: jumphostAdministratorPassword
    administratorUsername: administratorUsername
    adoOrganizationUrl: adoOrganizationUrl
    adoToken: adoToken
    githubRepositoryUrl: githubRepositoryUrl
    githubToken: githubToken
  }
}

/*
** Enterprise App Patterns Telemetry
** A non-billable resource deployed to Azure to identify the template
*/
@description('Enable usage and telemetry feedback to Microsoft.')
param enableTelemetry bool = true

module telemetry './modules/telemetry.bicep' = if (enableTelemetry) {
  name: '${prefix}-telemetry'
  params: {
    deploymentSettings: primaryDeploymentSettings
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

// Hub resources
output BASTION_NAME string = willDeployHubNetwork ? hubNetwork.outputs.bastion_name : ''
output BASTION_RESOURCE_GROUP string = willDeployHubNetwork ? resourceGroups.outputs.hub_resource_group_name : ''
output bastion_hostname string = willDeployHubNetwork ? hubNetwork.outputs.bastion_hostname : ''
output firewall_hostname string = willDeployHubNetwork ? hubNetwork.outputs.firewall_hostname : ''

// Spoke resources
output build_agent string = installBuildAgent ? buildAgent.outputs.build_agent_hostname : ''
output JUMPHOST_RESOURCE_ID string = isNetworkIsolated ? hubNetwork.outputs.jumphost_resource_id : ''

// Application resources
output AZURE_RESOURCE_GROUP string = resourceGroups.outputs.application_resource_group_name
output SECONDARY_RESOURCE_GROUP string = isMultiLocationDeployment ? resourceGroups2.outputs.application_resource_group_name : 'not-deployed'
output service_managed_identities object[] = application.outputs.service_managed_identities
output service_web_endpoints string[] = application.outputs.service_web_endpoints
output AZURE_OPS_VAULT_NAME string = isNetworkIsolated ? hubNetwork.outputs.key_vault_name : application.outputs.key_vault_name

// Local development values
output AZURE_PRINCIPAL_TYPE = principalType
output APP_CONFIG_SERVICE_URI string = application.outputs.app_config_uri
output WEB_URI string = application.outputs.web_uri
output SQL_DATABASE_NAME string = application.outputs.sql_database_name
output SQL_SERVER_NAME string = application.outputs.sql_server_name
