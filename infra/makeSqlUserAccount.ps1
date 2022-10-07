<#
.SYNOPSIS
    Will make the SQL user account required to authenticate with Azure AD to Azure SQL Database.
.DESCRIPTION
  Placeholder

  <This command should only be run after using the azd command to deploy resources to Azure>
.PARAMETER ResourceGroupName
    Name of resource group containing the environment that was created by the azd command..
#>

Param(
  [Alias("g")]
  [Parameter(Mandatory = $true, HelpMessage = "Name of the resource group that was created by azd")]
  [String]$ResourceGroupName
)

if (Get-Module -ListAvailable -Name SqlServer) {
  Write-Debug "SQL Already Installed"
} 
else {
  try {
    Install-Module -Name SqlServer -AllowClobber -Confirm:$False -Force  
  }
  catch [Exception] {
    $_.message 
    exit
  }
}

Import-Module -Name SqlServer

$groupExists = (az group exists -n $ResourceGroupName)
if ($groupExists -eq 'false') {
  Write-Error "FATAL ERROR: $ResourceGroupName could not be found in the current subscription"
  exit 6
}
else {
  Write-Debug "Found resource group named: $ResourceGroupName"
}

$azureAdUsername = (az ad signed-in-user show --query userPrincipalName -o tsv)
Write-Debug "`$azureAdUsername='$azureAdUsername'"
$objectIdForCurrentUser = (az ad signed-in-user show --query id -o tsv)
Write-Debug "`$objectIdForCurrentUser='$objectIdForCurrentUser'"

$keyVaultName = (az resource list -g $ResourceGroupName --query "[?type=='Microsoft.KeyVault/vaults' && name.starts_with(@, 'admin')].name" -o tsv)

Write-Debug "`$keyVaultName='$keyVaultName'"

$databaseServer = (az resource list -g $ResourceGroupName --query "[?type=='Microsoft.Sql/servers'].name" -o tsv)
Write-Debug "`$databaseServer='$databaseServer'"

$databaseServerFqdn = (az sql server show -n $databaseServer -g $ResourceGroupName --query fullyQualifiedDomainName -o tsv)
Write-Debug "`$databaseServerFqdn='$databaseServerFqdn'"

$databaseName = (az resource list -g $ResourceGroupName --query "[?type=='Microsoft.Sql/servers/databases' && name.ends_with(@, 'database')].tags.displayName" -o tsv)
Write-Debug "`$databaseName='$databaseName'"

$sqlAdmin = (az keyvault secret show --vault-name $keyVaultName -n sqlAdministratorLogin --query value -o tsv)
$sqlPassword = (az keyvault secret show --vault-name $keyVaultName -n sqlAdministratorPassword --query value -o tsv)

# disable Azure AD only admin access
az sql server ad-only-auth disable -n $databaseServer -g $ResourceGroupName

# translate applicationId into SID
[guid]$guid = [System.Guid]::Parse($objectIdForCurrentUser)

foreach ($byte in $guid.ToByteArray()) {
  $byteGuid += [System.String]::Format("{0:X2}", $byte)
}
$Sid = "0x" + $byteGuid

# Prepare SQL cmd to CREATE USER
$createUserSQL = "IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'$azureAdUsername') create user [$azureAdUsername] with sid = $Sid, type = E;"

# Connect as SQL Admin acct and execute SQL cmd
Invoke-Sqlcmd -ServerInstance $databaseServerFqdn -database $databaseName -Username $sqlAdmin -Password $sqlPassword -Query $createUserSQL
Write-Debug "Created user"

Invoke-Sqlcmd -ServerInstance $databaseServerFqdn -database 'master' -Username $sqlAdmin -Password $sqlPassword -Query $createUserSQL
Write-Debug "Created for root db"

# Prepare SQL cmd to grant db_owner role
$grantDbOwner = "IF NOT EXISTS (SELECT * FROM sys.database_principals p JOIN sys.database_role_members db_owner_role ON db_owner_role.member_principal_id = p.principal_id JOIN sys.database_principals role_names ON role_names.principal_id = db_owner_role.role_principal_id AND role_names.[name] = 'db_owner' WHERE p.[name]=N'$azureAdUsername') ALTER ROLE db_owner ADD MEMBER [$azureAdUsername];"

# Connect as SQL Admin acct and execute SQL cmd
Invoke-Sqlcmd -ServerInstance $databaseServerFqdn -database $databaseName -Username $sqlAdmin -Password $sqlPassword -Query $grantDbOwner

Write-Debug "Granted db_owner"

# enable Azure AD only admin access
az sql server ad-only-auth enable -n $databaseServer -g $ResourceGroupName