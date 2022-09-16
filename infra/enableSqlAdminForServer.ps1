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