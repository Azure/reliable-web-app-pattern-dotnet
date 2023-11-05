#Requires -Version 7.0

<#
.SYNOPSIS
    Used to enable Sql Authentication only for target Azure SQL Server
.DESCRIPTION
    Used to enable Sql Authentication only for target Azure SQL Server
    
    NOTE: This script is not intended to be run from a local environment.
    This script is run by azd during devOps deployment. This script handles rolling back auth changes
    that would block the createSqlAcctForManagedIdentity.ps1 scripts from connecting when run as a deploymentScript
    https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/224

    This script provides a workflow to automatically configure the deployed Azure resources and make it easier to get
    started. It is not intended as part of a recommended best practice as we do not recommend deploying Azure SQL
    with network configurations that would allow a deployment script such as this to connect.

.PARAMETER SqlServerName
    A required parameter for the name of the Azure SQL Server instance.
.PARAMETER ResourceGroupName
    A required parameter for the name of resource group that contains the environment that was
    created by the azd command.
#>

Param(
    [Parameter(Mandatory = $true)][string]$SqlServerName,
    [Parameter(Mandatory = $true)][string]$ResourceGroupName
)

# check if resource group exists
if (!(Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    Exit
}

$DoesSqlServerExist = Get-AzResource -ResourceGroupName $ResourceGroupName -ODataQuery "ResourceType eq 'Microsoft.Sql/servers'"

if ($DoesSqlServerExist) {
    Write-Host "Disabling Ad only admin"
    Disable-AzSqlServerActiveDirectoryOnlyAuthentication -ServerName $SqlServerName -ResourceGroupName $ResourceGroupName
}