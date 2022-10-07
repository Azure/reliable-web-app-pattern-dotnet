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
    created by the azd command. The cmdlet will populate the App Config Svc and Key
    Vault services in this resource group with Azure AD app registration config data.
#>

Param(
    [Alias("g")]
    [Parameter(Mandatory = $true)][string]
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

$mySqlServer = (az resource list -g $ResourceGroupName --query "[?type=='Microsoft.Sql/servers'].name" -o tsv)

Write-Debug "`$mySqlServer = '$mySqlServer'"

$customRuleName = "devbox_$((Get-Date).ToString("yyyy-mm-dd_HH-MM-ss"))"

Write-Debug "`$customRuleName = '$customRuleName'"

az sql server firewall-rule create -g $ResourceGroupName -s $mySqlServer -n $customRuleName --start-ip-address $myIpAddress --end-ip-address $myIpAddress

#### support multi-regional deployment ####

$secondaryResourceGroupName = $ResourceGroupName.Substring(0, $ResourceGroupName.Length - 2) + "secondary-rg"
$group2Exists = (az group exists -n $secondaryResourceGroupName)
if ($group2Exists -eq 'false') {
    $secondaryResourceGroupName = ''
}

Write-Debug "`$secondaryResourceGroupName='$secondaryResourceGroupName'"

if ($secondaryResourceGroupName.Length -gt 0) {
    Write-Debug 'Searching for secondary sql server'
    $mySqlServer = (az resource list -g $secondaryResourceGroupName --query "[?type=='Microsoft.Sql/servers'].name" -o tsv)

    Write-Debug "`$mySqlServer='$mySqlServer'"

    if ($mySqlServer.Length -gt 0) {
        Write-Debug 'Setting firewall on secondary sql'
        az sql server firewall-rule create -g $secondaryResourceGroupName -s $mySqlServer -n "devbox_$(Get-Date).ToString("yyyy-mm-dd_HH-MM-ss")" --start-ip-address $myIpAddress --end-ip-address $myIpAddress
    }
}