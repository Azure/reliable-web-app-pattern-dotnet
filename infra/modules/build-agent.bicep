targetScope = 'subscription'

/*
** Create a Build Agent for Devops
** All Rights Reserved
**
***************************************************************************
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

// From: infra/types/BuildAgentSettings.bicep
@description('Describes the required settings for a Azure DevOps Pipeline runner')
type AzureDevopsSettings = {
  @description('The URL of the Azure DevOps organization to use for this agent')
  organizationUrl: string

  @description('The Personal Access Token (PAT) to use for the Azure DevOps agent')
  token: string
}

@description('Describes the required settings for a GitHub Actions runner')
type GithubActionsSettings = {
  @description('The URL of the GitHub repository to use for this agent')
  repositoryUrl: string

  @description('The Personal Access Token (PAT) to use for the GitHub Actions runner')
  token: string
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

@description('The ID of the managed identity to use as the identity for communicating with other services.')
param managedIdentityId string

@description('The list of subnets that are used for linking into the virtual network if using network isolation.')
param subnets object

/*
** Settings
*/
@secure()
@minLength(8)
@description('The password for the administrator account on the build agent.')
param administratorPassword string

@minLength(8)
@description('The username for the administrator account on the build agent.')
param administratorUsername string

@description('The URL of the Azure DevOps organization.  If this and the adoToken is provided, then an Azure DevOps build agent will be deployed.')
param adoOrganizationUrl string = ''

@description('The access token for the Azure DevOps organization.  If this and the adoOrganizationUrl is provided, then an Azure DevOps build agent will be deployed.')
param adoToken string = ''

// Settings for setting up a build agent for GitHub Actions
@description('The URL of the GitHub repository.  If this and the githubToken is provided, then a GitHub Actions build agent will be deployed.')
param githubRepositoryUrl string = ''

@description('The personal access token for the GitHub repository.  If this and the githubRepositoryUrl is provided, then a GitHub Actions build agent will be deployed.')
param githubToken string = ''

// ========================================================================
// VARIABLES
// ========================================================================

// The tags to apply to all resources in this workload
var moduleTags = union(deploymentSettings.tags, deploymentSettings.workloadTags, {
  WorkloadType: 'Devops'
})

// ========================================================================
// EXISTING RESOURCES
// ========================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceNames.spokeResourceGroup
}

// ========================================================================
// NEW RESOURCES
// ========================================================================

module buildAgent '../core/compute/windows-buildagent.bicep' = {
  name: 'devops-build-agent'
  scope: resourceGroup
  params: {
    name: resourceNames.buildAgent
    location: deploymentSettings.location
    tags: moduleTags

    // Dependencies
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    managedIdentityId: managedIdentityId
    subnetId: subnets[resourceNames.spokeDevopsSubnet].id

    // Settings
    administratorPassword: administratorPassword
    administratorUsername: administratorUsername
    azureDevopsSettings: !empty(adoOrganizationUrl) && !empty(adoToken) ? {
      organizationUrl: adoOrganizationUrl
      token: adoToken
    } : null
    diagnosticSettings: diagnosticSettings
    githubActionsSettings: !empty(githubRepositoryUrl) && !empty(githubToken) ? {
      repositoryUrl: githubRepositoryUrl
      token: githubToken
    } : null
  }
}

// ========================================================================
// NEW RESOURCES
// ========================================================================

output build_agent_id string = buildAgent.outputs.id
output build_agent_name string = buildAgent.outputs.name
output build_agent_hostname string = buildAgent.outputs.computer_name
