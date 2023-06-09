#Requires -Version 7.0

<#
.SYNOPSIS
    Used to create Sql Account for Managed Identity
.DESCRIPTION
    Creates a new Sql Account for the Managed Identity service principal and grants account db_owner role

    Also configures the Sql Database for AAD authentication only

    NOTE: This script is not intended to be run from a local environment.
    This script is run by azd during devOps deployment.
    For the local environment version of this script, please see makeSqlUserAccount.ps1

    This script provides a workflow to automatically configure the deployed Azure resources and make it easier to get
    started. It is not intended as part of a recommended best practice as we do not recommend deploying Azure SQL
    with network configurations that would allow a deployment script such as this to connect.

    We recommend handling this one-time process as part of your SQL data migration process
    More details can be found in our docs for Azure SQL server
    https://learn.microsoft.com/en-us/azure/app-service/tutorial-connect-msi-sql-database?tabs=windowsclient%2Cef%2Cdotnet

    Assumes the service principal that will connect to SQL has been set as the Azure AD Admin
    This was handled by the bicep templates
    see https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure?view=azuresql&tabs=azure-powershell#azure-portal
.PARAMETER ServerName
    A required parameter for the name of target Azure SQL Server.
.PARAMETER ResourceGroupName
    A required parameter for the name of resource group that contains the environment that was
    created by the azd command.
.PARAMETER ServerUri
    A required parameter for the Uri of target Azure SQL Server.
.PARAMETER CatalogName
    A required parameter for the name the Azure SQL Database name used.
.PARAMETER ApplicationId
    A required parameter for the Managed Identity's Application ID used to generate its SID 
    used for creating a user in SQL.
.PARAMETER ManagedIdentityName
    A required parameter for the name of Managed Identity that will be used.
.PARAMETER SqlAdminLogin
    A required parameter for the SQL Administrator Login used.
.PARAMETER SqlAdminPwd
    A required parameter for the SQL Administrator Password used.
.PARAMETER IsProd
    A required parameter indicating Production environment is being used.
#>

Param(
  [Parameter(Mandatory = $true)][string]$ServerName,
  [Parameter(Mandatory = $true)][string]$ResourceGroupName,
  [Parameter(Mandatory = $true)][string]$ServerUri,
  [Parameter(Mandatory = $true)][string]$CatalogName,
  [Parameter(Mandatory = $true)][string]$ApplicationId,
  [Parameter(Mandatory = $true)][string]$ManagedIdentityName,
  [Parameter(Mandatory = $true)][string]$SqlAdminLogin,
  [Parameter(Mandatory = $true)][string]$SqlAdminPwd,
  [Parameter(Mandatory = $true)][bool]$IsProd
)

# Make Invoke-Sqlcmd available
Install-Module -Name SqlServer -Force
Import-Module -Name SqlServer

# translate applicationId into SID
[guid]$guid = [System.Guid]::Parse($ApplicationId)

foreach ($byte in $guid.ToByteArray()) {
  $byteGuid += [System.String]::Format("{0:X2}", $byte)
}
$Sid = "0x" + $byteGuid

# Prepare SQL cmd to CREATE USER
$CreateUserSQL = "IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'$ManagedIdentityName') create user [$ManagedIdentityName] with sid = $Sid, type = E;"

# Connect as SQL Admin acct and execute SQL cmd
Invoke-Sqlcmd -ServerInstance $ServerUri -database $CatalogName -Username $SqlAdminLogin -Password $SqlAdminPwd -Query $CreateUserSQL

# Prepare SQL cmd to grant db_owner role
$GrantDbOwner = "IF NOT EXISTS (SELECT * FROM sys.database_principals p JOIN sys.database_role_members db_owner_role ON db_owner_role.member_principal_id = p.principal_id JOIN sys.database_principals role_names ON role_names.principal_id = db_owner_role.role_principal_id AND role_names.[name] = 'db_owner' WHERE p.[name]=N'$ManagedIdentityName') ALTER ROLE db_owner ADD MEMBER [$ManagedIdentityName];"

# Connect as SQL Admin acct and execute SQL cmd
Invoke-Sqlcmd -ServerInstance $ServerUri -database $CatalogName -Username $SqlAdminLogin -Password $SqlAdminPwd -Query $GrantDbOwner

# Restrict access to Azure AD users
Enable-AzSqlServerActiveDirectoryOnlyAuthentication -ServerName $ServerName -ResourceGroupName $ResourceGroupName

