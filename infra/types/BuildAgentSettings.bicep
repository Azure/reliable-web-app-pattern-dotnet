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
