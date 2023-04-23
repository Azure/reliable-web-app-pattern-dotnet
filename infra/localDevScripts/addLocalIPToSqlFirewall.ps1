#Requires -Version 7.0

<#
.SYNOPSIS
    Used by developers to get access to Azure SQL database
.DESCRIPTION
    Makes a web request to a public site to retrieve the user's public IP address
    and then adds that IP address to the Azure SQL Database Firewall as an allowed connection.

    NOTE: This functionality assumes that the web app, app configuration service, and app
    service have already been successfully deployed.

.PARAMETER ResourceGroupName
    A required parameter for the name of resource group that contains the environment that was
    created by the azd command.
#>

Param(
    [Alias("g")]
    [Parameter(Mandatory = $true, HelpMessage = "Name of the resource group that was created by azd")]
    $ResourceGroupName
)

if ($ResourceGroupName -eq "-rg") {
    Write-Error "FATAL ERROR: $ResourceGroupName could not be found in the current subscription"
    exit 5
}

$groupExists = (az group exists -n "$ResourceGroupName")
if ($groupExists -eq 'false') {
    Write-Error "FATAL ERROR: $ResourceGroupName could not be found in the current subscription"
    exit 6
}
else {
    Write-Debug "Found resource group named: $ResourceGroupName"
}

Write-Debug "`$ResourceGroupName = '$ResourceGroupName'"

$myIpAddress = (Invoke-WebRequest ipinfo.io/ip)

Write-Debug "`$myIpAddress = '$myIpAddress'"

# updated az resource selection to filter to first based on https://github.com/Azure/azure-cli/issues/25214
$mySqlServer = (az resource list -g $ResourceGroupName --query "[?type=='Microsoft.Sql/servers'].name | [0]" -o tsv)

Write-Debug "`$mySqlServer = '$mySqlServer'"

$customRuleName = "devbox_$((Get-Date).ToString("yyyy-mm-dd_HH-MM-ss"))"

Write-Debug "`$customRuleName = '$customRuleName'"

# Resolves permission constraint that prevents the deploymentScript from running this command
# https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/134
az sql server update -n $mySqlServer -g $ResourceGroupName --set publicNetworkAccess="Enabled" > $null

Write-Debug "Change Rule"

az sql server firewall-rule create -g $ResourceGroupName -s $mySqlServer -n $customRuleName --start-ip-address $myIpAddress --end-ip-address $myIpAddress

Write-Host "Successful" -ForegroundColor Green -NoNewline; Write-Host " this client's IP address was added to Azure SQL Firewall"