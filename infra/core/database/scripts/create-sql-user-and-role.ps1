#Requires -Version 7.0

<#
.SYNOPSIS
    Creates a SQL user and assigns the user account to one or more roles.

.DESCRIPTION
    During an application deployment, the managed identity (and potentially the developer identity)
    must be added to the SQL database as a user and assigned to one or more roles.  This script
    does exactly that using the owner managed identity.

.PARAMETER SqlServerName
    The name of the SQL Server resource
.PARAMETER SqlDatabaseName
    The name of the SQL Database resource
.PARAMETER ObjectId
    The Object (Principal) ID of the user to be added.
.PARAMETER DisplayName
    The display name of the user to be added.  This is optional.  If not provided, the Get-AzADUser cmdlet
    will be used to retrieve the display name.
.PARAMETER IsServicePrincipal
    True if the ObjectId refers to a service principal rather than a user.
.PARAMETER DatabaseRoles
    The comma-separated list of database roles that need to be assigned to the user.
#>

Param(
    [string] $SqlServerName,
    [string] $SqlDatabaseName,
    [string] $ObjectId,
    [string] $DisplayName,
    [switch] $IsServicePrincipal = $false,
    [string[]] $DatabaseRoles = @('db_datareader','db_datawriter')
)

function Resolve-Module($moduleName) {
    # If module is imported; say that and do nothing
    if (Get-Module | Where-Object { $_.Name -eq $moduleName }) {
        Write-Debug "Module $moduleName is already imported"
    } elseif (Get-Module -ListAvailable | Where-Object { $_.Name -eq $moduleName }) {
        Import-Module $moduleName
    } elseif (Find-Module -Name $moduleName | Where-Object { $_.Name -eq $moduleName }) {
        Install-Module $moduleName -Force -Scope CurrentUser
        Import-Module $moduleName
    } else {
        Write-Error "Module $moduleName not found"
        Write-Host "###vso[task.complete result=Failed;]Failed"
        [Environment]::exit(1)
    }
}

function ConvertTo-Sid($applicationId) {
    [System.Guid]$guid = [System.Guid]::Parse($applicationId)
    foreach ($byte in $guid.ToByteArray()) {
        $byteGuid += [System.String]::Format("{0:X2}", $byte)
    }
    return "0x" + $byteGuid
}

###
### MAIN SCRIPT
###
Resolve-Module -moduleName SqlServer

# Get the SID for the ObjectId we are using
$Sid = ConvertTo-Sid -applicationId $ObjectId

# Construct the SQL to create the user.
$sqlList = [System.Collections.ArrayList]@()

$UserCreationOpt = if ($IsServicePrincipal) { "WITH sid = $($Sid), type = E" } else { "FROM EXTERNAL PROVIDER" }
$CreateUserSql = @"
IF NOT EXISTS (
    SELECT * FROM sys.database_principals WHERE name = N'$($DisplayName)'
) 
CREATE USER [$($DisplayName)] $($UserCreationOpt);

"@
$sqlList.Add($CreateUserSql) | Out-Null 

foreach ($role in $DatabaseRoles) {
    $GrantRoleSql = @"
IF NOT EXISTS (
    SELECT * FROM sys.database_principals p 
        JOIN sys.database_role_members $($role)_role ON $($role)_role.member_principal_id = p.principal_id 
        JOIN sys.database_principals role_names ON role_names.principal_id = $($role)_role.role_principal_id AND role_names.[name] = '$($role)' 
        WHERE p.[name]=N'$($DisplayName)'
    ) 
ALTER ROLE $($role) ADD MEMBER [$($DisplayName)];

"@
    $sqlList.Add($GrantRoleSql) | Out-Null
}

# Execute the SQL Command on Azure SQL.
foreach ($sqlcmd in $sqlList) {
    try {
        $sqlcmd | Write-Output
        $token = (Get-AzAccessToken -ResourceUrl https://database.windows.net/).Token
        Invoke-SqlCmd -ServerInstance "$SqlServerName.database.windows.net" -Database $SqlDatabaseName -AccessToken $token -Query $sqlcmd -ErrorAction 'Stop' -StatisticsVariable 'stats'
        $stats | ConvertTo-Json -Depth 10 | Write-Output
    } catch {
        Write-Error $_.Exception.Message
        Write-Host "###vso[task.complete result=Failed;]Failed"
        [Environment]::exit(1)
    }
}

