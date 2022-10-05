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
.PARAMETER SecondaryResourceGroupName
    An optional parameter that describes the name of the second resource group that contains the
    resources deployed by the azd command. The cmdlet will populate the App Config Svc and Key
    Vault services in this resource group with Azure AD app registration config data.
#>

$myIpAddress = (Invoke-WebRequest ipinfo.io/ip)
$mySqlServer = (az resource list -g "$myEnvironmentName-rg" --query "[?type=='Microsoft.Sql/servers'].name" -o tsv)
az sql server firewall-rule create -g "$myEnvironmentName-rg" -s $mySqlServer -n "devbox_$(date +"%Y-%m-%d_%I-%M-%S")" --start-ip-address $myIpAddress --end-ip-address $myIpAddress