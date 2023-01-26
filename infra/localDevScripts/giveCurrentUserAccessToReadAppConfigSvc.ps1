# Does not require pwsh

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
.PARAMETER Web
    Print the json snippet for the api web app. Defaults to False.
.PARAMETER Api
    Print the json snippet for the front-end web app. Defaults to False.
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