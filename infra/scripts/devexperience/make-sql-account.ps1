<#
.SYNOPSIS
This script creates a SQL account for a specified Entra ID account so that the user can connect to Azure SQL.

.PARAMETER ResourceGroup
The name of the resource group where the SQL Server is located.

.PARAMETER SqlServerName
The name of the SQL Server.

.PARAMETER SqlDatabaseName
The name of the SQL database.

.PARAMETER AccountAlias
The account alias of the Entra ID account to be added to Azure SQL.

.PARAMETER AccountId
The ID of the Entra ID account to be added to Azure SQL.

.EXAMPLE
./make-sql-account.ps1 -ResourceGroup "myResourceGroup" -SqlServerName "mySqlServer" -SqlDatabaseName "mySqlDatabase" -AccountId "mySqlAccount" -Credential $Creds
Creates a SQL account with the specified parameters.

#>

Param(
    [Parameter(Mandatory=$true)]
    [string] $ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string] $SqlServerName,

    [Parameter(Mandatory=$true)]
    [string] $SqlDatabaseName,

    [Parameter(Mandatory=$true)]
    [string] $AccountAlias,

    [Parameter(Mandatory=$true)]
    [string] $AccountId,

    [Parameter(Mandatory=$true)]
    [System.Management.Automation.PSCredential]$Credential
)

<#
.SYNOPSIS
    Tests to ensure that the Powershell module we need is installed and imported before use.
.PARAMETER ModuleName
    The name of the module to test for.
#>
function Test-ModuleImported {
    param(
        [Parameter(Mandatory=$true)]
        [string] $ModuleName
    )

    if ((Get-Module -ListAvailable -Name $ModuleName) -and (Get-Module -Name $ModuleName -ErrorAction SilentlyContinue)) {
        Write-Verbose "The '$($ModuleName)' module is installed and imported."
    }
    else {
        $SavedVerbosePreference = $global:VerbosePreference
        try {
            Write-Verbose "Importing '$($ModuleName)' module"
            $global:VerbosePreference = 'SilentlyContinue'
            Import-Module -Name $ModuleName -ErrorAction Stop
            $global:VerbosePreference = $SavedVerbosePreference
            Write-Verbose "The '$($ModuleName)' module is imported successfully."
        }
        catch {
            Write-Error "Failed to import the '$($ModuleName)' module. Please install the '$($ModuleName)' module before running this script."
            exit 12
        }
        finally {
            $global:VerbosePreference = $SavedVerbosePreference
        }
    }
}

<#
.SYNOPSIS
    Checks to ensure that the user is authenticated with Azure before running the script.
#>
function Test-AzureConnected {
    if (Get-AzContext -ErrorAction SilentlyContinue) {
        Write-Verbose "The user is authenticated with Azure."
    }
    else {
        Write-Error "You are not authenticated with Azure. Please run 'Connect-AzAccount' to authenticate before running this script."
        exit 10
    }
}

Test-ModuleImported -ModuleName Az.Resources
Test-ModuleImported -ModuleName SqlServer
Test-AzureConnected

# Prompt formatting features

$defaultColor = if ($PSVersionTable.PSVersion.Major -ge 6) { "`e[0m" } else { "" }
$successColor = if ($PSVersionTable.PSVersion.Major -ge 6) { "`e[32m" } else { "" }

[guid]$guid = [System.Guid]::Parse($accountId)

foreach ($byte in $guid.ToByteArray()) {
  $byteGuid += [System.String]::Format("{0:X2}", $byte)
}
$Sid = "0x" + $byteGuid

$fullyQualifiedDomainName = (Get-AzSqlServer -ResourceGroupName $ResourceGroup -ServerName $SqlServerName).FullyQualifiedDomainName


# Prepare SQL cmd to CREATE USER
$createUserSQL = "IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'$AccountAlias') create user [$AccountAlias] with sid = $Sid, type = E;"

# Connect as SQL Admin acct and execute SQL cmd
Invoke-Sqlcmd -ServerInstance $fullyQualifiedDomainName -database $sqlDatabaseName -Credential $Credential -Query $createUserSQL
Write-Host "`tCreated user"

Invoke-Sqlcmd -ServerInstance $fullyQualifiedDomainName -database 'master' -Credential $Credential -Query $createUserSQL
Write-Host "`tCreated for root db"

# Prepare SQL cmd to grant db_owner role
$grantDbOwner = "IF NOT EXISTS (SELECT * FROM sys.database_principals p JOIN sys.database_role_members db_owner_role ON db_owner_role.member_principal_id = p.principal_id JOIN sys.database_principals role_names ON role_names.principal_id = db_owner_role.role_principal_id AND role_names.[name] = 'db_owner' WHERE p.[name]=N'$AccountAlias') ALTER ROLE db_owner ADD MEMBER [$AccountAlias];"

# Connect as SQL Admin acct and execute SQL cmd
Invoke-Sqlcmd -ServerInstance $fullyQualifiedDomainName -database $sqlDatabaseName -Credential $Credential -Query $grantDbOwner

Write-Host "`tGranted db_owner"

Write-Host "`nFinished $($successColor)successfully$($defaultColor)."
Write-Host "An account for the current user was created in Azure SQL"