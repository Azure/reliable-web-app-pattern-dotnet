targetScope = 'resourceGroup'

/*
** Windows 11 Build Agent
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates a Windows 11 VM with appropriate capabilities to act as a
** Build Agent with either Azure DevOps or GitHub Actions.
*/

// ========================================================================
// USER-DEFINED TYPES
// ========================================================================

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

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The Azure region for the resource.')
param location string

@description('The name of the primary resource')
param name string

@description('The tags to associate with this resource.')
param tags object = {}

/*
** Dependencies
*/
@description('The ID of a user-assigned managed identity to use as the identity for this resource.  Use a blank string for a system-assigned identity.')
param managedIdentityId string = ''

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

@description('The subnet ID to use for the resource.')
param subnetId string

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

@description('If provided, the Azure DevOps settings to use for the build agent.')
param azureDevopsSettings AzureDevopsSettings?

@description('If provided, the GitHub Actions settings to use for the build agent.')
param githubActionsSettings GithubActionsSettings?

@minLength(3)
@maxLength(15)
@description('The name of the windows PC.  By default, this will be automatically constructed by the resource name.')
param computerWindowsName string?

@description('If true, join the computer to the Azure AD domain.')
param joinToAzureAd bool = true

@description('The SKU for the virtual machine.')
param sku string = 'Standard_B2ms'

@description('If true, install the Azure CLI, SSMS, and git on the machine.')
param installTools bool = true

// ========================================================================
// VARIABLES
// ========================================================================

var identity = !empty(managedIdentityId) ? {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${managedIdentityId}': {}
  }
} : {
  type: 'SystemAssigned'
}

var validComputerName = replace(replace(name, '-', ''), '_', '')
var computerName = !empty(computerWindowsName) ? computerWindowsName : length(validComputerName) > 15 ? substring(validComputerName, 0, 15) : validComputerName

var installToolsOption = installTools ? ' -install_clis -install_ssms' : ''

var azureDevopsOption = azureDevopsSettings != null ? ' -ado_organization "${azureDevopsSettings!.organizationUrl}" -ado_token "${azureDevopsSettings!.token}"' : ''
var githubActionsOption = githubActionsSettings != null ? ' -github_repository "${githubActionsSettings!.repositoryUrl}" -github_token "${githubActionsSettings!.token}"' : ''
var doInstall = azureDevopsSettings != null || githubActionsSettings != null


// This is the URL to the App Service Landing Zone Accelerator GitHub repository.
// See: https://github.com/Azure/appservice-landing-zone-accelerator
var landingZoneAcceleratorUrl = 'https://raw.githubusercontent.com/Azure/appservice-landing-zone-accelerator/main/scenarios/shared/scripts/win-devops-vm-extensions'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = if (doInstall) {
  name: 'nic-${name}'
  location: location
  tags: tags
  properties: {
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-03-01' = if (doInstall) {
  name: name
  location: location
  tags: tags
  identity: identity
  properties: {
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    hardwareProfile: {
      vmSize: sku
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    osProfile: {
      adminPassword: administratorPassword
      adminUsername: administratorUsername
      computerName: computerName
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
          enableHotpatching: false
        }
        enableVMAgentPlatformUpdates: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-11'
        sku: 'win11-22h2-pro'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
  }
}

resource aadLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = if (doInstall && joinToAzureAd) {
  name: 'AADLoginForWindows'
  location: location
  parent: virtualMachine
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

resource postDeploymentScript 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = if (doInstall) {
  name: 'postDeploymentScript'
  location: location
  parent: virtualMachine
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${landingZoneAcceleratorUrl}/post-deployment.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File post-deployment.ps1${installToolsOption}${azureDevopsOption}${githubActionsOption}'
    }
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (doInstall && diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
  name: '${name}-diagnostics'
  scope: virtualMachine
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: []
    metrics: [
      {
        category: 'AllMetrics'
        enabled: diagnosticSettings!.enableMetrics
      }
    ]
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = virtualMachine.id
output name string = virtualMachine.name

output computer_name string = computerName!
