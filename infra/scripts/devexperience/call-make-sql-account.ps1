<#
.SYNOPSIS
Calls the make-sql-account.ps1 script to create a SQL account for a given resource group, SQL server, and database.

.DESCRIPTION
This script retrieves the necessary parameters from the AZD environment variables and Key Vault, and then calls the make-sql-account.ps1 script with the appropriate arguments.

.PARAMETER resourceGroupName
The name of the Azure resource group where the SQL server and database are located.

.PARAMETER sqlServerName
The name of the SQL server.

.PARAMETER sqlDatabaseName
The name of the SQL database.

.PARAMETER keyVaultName
The name of the Azure Key Vault where the SQL administrator credentials are stored.

.EXAMPLE
./call-make-sql-account.ps1

This example demonstrates how to call the script to create a SQL account using the default environment variables and Key Vault.

#>

$resourceGroupName = ((azd env get-values --output json | ConvertFrom-Json).AZURE_RESOURCE_GROUP)
$sqlServerName = ((azd env get-values --output json | ConvertFrom-Json).SQL_SERVER_NAME)
$sqlDatabaseName = ((azd env get-values --output json | ConvertFrom-Json).SQL_DATABASE_NAME)
$keyVaultName = ((azd env get-values --output json | ConvertFrom-Json).AZURE_OPS_VAULT_NAME)

$sqlAdmin = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "Application--SqlAdministratorUsername" -AsPlainText)
$secureSqlPassword = ConvertTo-SecureString -String (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "Application--SqlAdministratorPassword" -AsPlainText) -AsPlainText -Force

$accountId = (Get-AzContext).Account.ExtendedProperties["HomeAccountId"].Split(".")[0]
$accountAlias = (Get-AzContext).Account.Id

$Cred = New-Object System.Management.Automation.PSCredential ($sqlAdmin, $secureSqlPassword)

Write-Host "Calling make-sql-account.ps1 for group:'$resourceGroupName'..."

./infra/scripts/devexperience/make-sql-account.ps1 `
    -ResourceGroup $resourceGroupName `
    -SqlServerName $sqlServerName `
    -SqlDatabaseName $sqlDatabaseName `
    -AccountAlias $accountAlias `
    -AccountId $accountId `
    -Credential $Cred