targetScope = 'resourceGroup'

/*
** Ubuntu VM Jumpbox
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates an Ubuntu VM with appropriate capabilities to act as a
** jumpbox
*/

import { DiagnosticSettings } from '../../types/DiagnosticSettings.bicep'

// ========================================================================
// PARAMETERS
// ========================================================================

@description('The diagnostic settings to use for logging and metrics.')
param diagnosticSettings DiagnosticSettings

@description('The name of the primary resource')
param name string

@minLength(3)
@maxLength(15)
@description('The name of the linux PC.  By default, this will be automatically constructed by the resource name.')
param computerLinuxName string?

@description('Username for the Virtual Machine. NOTE: this is not saved anywhere as Entra is used to manage SSH logins once created.')
param adminUsername string = newGuid()

@description('Password for admin. NOTE: this is not saved anywhere as Entra is used to manage SSH logins once created.')
@secure()
@minLength(8)
param adminPassword string = newGuid()

@description('The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version.')
@allowed([
  'Ubuntu-1804'
  'Ubuntu-2004'
  'Ubuntu-2204'
])
param ubuntuOSVersion string = 'Ubuntu-2204'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The size of the VM')
param vmSize string = 'Standard_B2ms'

@description('The tags to associate with this resource.')
param tags object = {}

@description('Users to add to VM management role for jumpbox')
param users string[]

/*
** Dependencies
*/

@description('The ID of the Log Analytics workspace to use for diagnostics and logging.')
param logAnalyticsWorkspaceId string = ''

@description('The subnet ID to use for the resource.')
param subnetId string

/*
** Settings
*/

// ========================================================================
// VARIABLES
// ========================================================================

// based on the images allowed we enable TrustedLaunch by default to opt-in to security features by default.
// this can be swapped to 'Standard' if the user wants to opt-out of TrustedLaunch
// Trusted launch guards against boot kits, rootkits, and kernel-level malware. 
// Learn more at https://learn.microsoft.com/en-us/azure/virtual-machines/trusted-launch
var securityType = 'TrustedLaunch'
var validComputerName = replace(replace(name, '-', ''), '_', '')
var computerName = !empty(computerLinuxName) ? computerLinuxName : length(validComputerName) > 15 ? substring(validComputerName, 0, 15) : validComputerName

var configScriptRepoUrl = 'https://raw.githubusercontent.com/KSchlobohm/reliable-web-app-vm-postconfiguration/main'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

var imageReference = {
  'Ubuntu-1804': {
    publisher: 'Canonical'
    offer: 'UbuntuServer'
    sku: '18_04-lts-gen2'
    version: 'latest'
  }
  'Ubuntu-2004': {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-focal'
    sku: '20_04-lts-gen2'
    version: 'latest'
  }
  'Ubuntu-2204': {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    version: 'latest'
  }
}

var securityProfileJson = {
  uefiSettings: {
    secureBootEnabled: true
    vTpmEnabled: true
  }
  securityType: securityType
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = {
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

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned' // Needed by the Entra extension
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
      imageReference: imageReference[ubuntuOSVersion]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    securityProfile: ((securityType == 'TrustedLaunch') ? securityProfileJson : null)
  }
  tags: tags
}

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if ((securityType == 'TrustedLaunch') && ((securityProfileJson.uefiSettings.secureBootEnabled == true) && (securityProfileJson.uefiSettings.vTpmEnabled == true))) {
  parent: virtualMachine
  name: 'GuestAttestation'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Security.LinuxAttestation'
    type: 'GuestAttestation'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      AttestationConfig: {
        MaaSettings: {
          maaEndpoint: substring('emptystring', 0, 0)
          maaTenantName: 'GuestAttestation'
        }
      }
    }
  }
}

resource postDeploymentScript 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: 'postDeploymentScript'
  location: location
  parent: virtualMachine
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      skipDos2Unix: false
    }
    protectedSettings: {
      commandToExecute: 'chmod +x post-deployment.sh && bash post-deployment.sh'
      fileUris: [
        '${configScriptRepoUrl}/post-deployment.sh'
      ]
    }
  }
}

resource aadsshlogin 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  name: 'aadsshlogin'
  location: location
  parent: virtualMachine
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADSSHLoginForLinux'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}

// Role id for Virtual Machine Administrator Login
var vmAdminLoginId = '1c0163c0-47e6-4577-8991-ea5c82e286e4'

resource vmAdminRoles 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for user in users: {
  name: guid(virtualMachine.name, resourceGroup().name, user)
  scope: virtualMachine
  properties: {
    principalType: 'User'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', vmAdminLoginId)
    principalId: user
  }
}]

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (diagnosticSettings != null && !empty(logAnalyticsWorkspaceId)) {
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

output id string = virtualMachine.id
output name string = virtualMachine.name

output computer_name string = computerName!
