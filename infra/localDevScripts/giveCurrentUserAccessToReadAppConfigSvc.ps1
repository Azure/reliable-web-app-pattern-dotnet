# Does not require pwsh

# This script is part of the sample's workflow for giving developers access
# to the resources that were deployed. Note that a better solution, beyond
# the scope of this demo, would be to associate permissions based on
# Azure AD groups so that all team members inherit access from Azure AD.
# https://learn.microsoft.com/en-us/azure/active-directory/roles/groups-concept
#
# This code may be repurposed for your scenario as desired
# but is not covered by the guidance in this content.

<#
.SYNOPSIS
    Will give the current user read access to Azure App Configuration Service
.DESCRIPTION
    This script supports the local development scenario by giving the current user RBAC access
    to the Azure App Configuration Service that was deployed by the AZD command in a previous step.

    The role $appConfigDataReaderRole='516239f1-63e1-4d78-a4de-a74fb236a071' is a
    well-known role from the list of Azure RBAC roles
    https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#app-configuration-data-reader

    <This command should only be run after using the azd command to deploy resources to Azure>
.PARAMETER ResourceGroupName
    Name of resource group containing the environment that was created by the azd command.
#>

Param(
  [Alias("g")]
  [Parameter(Mandatory = $true, HelpMessage = "Name of the resource group that was created by azd")]
  [String]$ResourceGroupName
)

$appConfigDataReaderRole='516239f1-63e1-4d78-a4de-a74fb236a071'
$currentUserObjectId=(az ad signed-in-user show --query "id")
$scopeId=(az group show -n $ResourceGroupName --query "id")
az role assignment create --role $appConfigDataReaderRole --assignee $currentUserObjectId --scope $scopeId