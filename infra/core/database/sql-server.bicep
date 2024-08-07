targetScope = 'resourceGroup'

/*
** This template creates an Azure SQL Server.
** Copyright (C) 2023 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Defines a SQL Server, with a user-assigned managed identity.
** The Server is separated from the database, to allow for multiple
** databases to be created on the same server.
*/

import { DiagnosticSettings } from '../../types/DiagnosticSettings.bicep'

type FirewallRules = {
  @description('The list of IP address CIDR blocks to allow access from.')
  allowedIpAddresses: string[]
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
@description('The Name of a user-assigned managed identity to use as the identity for this resource.  Use a blank string for a system-assigned identity.')
param managedIdentityName string = ''

/*
** Settings
*/
@description('Whether or not public endpoint access is allowed for this server')
param enablePublicNetworkAccess bool = true

@description('The firewall rules to install on the sql-server.')
param firewallRules FirewallRules?

// ========================================================================
// VARIABLES
// ========================================================================

var allowedCidrBlocks = firewallRules != null ? map(firewallRules!.allowedIpAddresses, ipaddr => {
  name: replace(replace(ipaddr, '.', '_'), '/','_')
  startIpAddress: parseCidr(ipaddr).firstUsable
  endIpAddress: parseCidr(ipaddr).lastUsable
}) : []

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    administrators: {
      azureADOnlyAuthentication: true
      login: managedIdentity.name
      principalType: 'User'
      sid: managedIdentity.properties.principalId
      tenantId: managedIdentity.properties.tenantId
    }
    publicNetworkAccess: enablePublicNetworkAccess || firewallRules != null ? 'Enabled' : 'Disabled'
    version: '12.0'
  }

  resource allowAzureServices 'firewallRules' = if (enablePublicNetworkAccess) {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      endIpAddress: '0.0.0.0'
      startIpAddress: '0.0.0.0'
    }
  }

  resource allowClientIps 'firewallRules' = [ for entry in allowedCidrBlocks: {
    name: 'AllowClientIp-${entry.name}'
    properties: {
      endIpAddress: entry.endIpAddress
      startIpAddress: entry.startIpAddress
    }
  }]

  resource auditSettings 'auditingSettings' = {
    name: 'default'
    properties: {
      state: diagnosticSettings.enableLogs ? 'Enabled' : 'Disabled'
      isAzureMonitorTargetEnabled: true
    }
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

output id string = sqlServer.id
output name string = sqlServer.name
output hostname string = sqlServer.properties.fullyQualifiedDomainName
