<#
.SYNOPSIS
    This script will be run by the Azure Developer CLI.

    Retrieves the public IP address of the current system, as seen by Azure.  To do this, it
    uses ipinfo.io as an external service.  Afterwards, it sets the AZD_IP_ADDRESS environment
    variable and sets the `azd env set` command to set it within Azure Developer CLI as well.
#>

$ipaddr = Invoke-RestMethod -Uri https://ipinfo.io/ip

# if $ipaddress is empty, exit with error
if ([string]::IsNullOrEmpty($ipaddr)) {
    Write-Error "Unable to retrieve public IP address"
    exit 1
}

$env:AZD_IP_ADDRESS = $ipaddr
azd env set AZD_IP_ADDRESS $ipaddr