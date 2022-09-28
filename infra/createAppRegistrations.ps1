<#
.SYNOPSIS
    Creates two Azure AD app registrations for the scalable-web-app-pattern-dotnet
    and saves the configuration data in App Configuration Svc and Key Vault.

    <This command should only be run after using the azd command to deploy resources to Azure>
.DESCRIPTION
    The Relecloud web app uses Azure AD to authetnicate and authorize the users that can
    make concert ticket purchases. To prove that the website is a trusted, and secure, resource
    the web app must handshake with Azure AD by providing the configuration settings like the following.
    - TenantID identifies which Azure AD instance holds the users that should be authorized
    - ClientID identifies which app this code says it represents
    - ClientSecret provides a secret known only to Azure AD, and shared with the web app, to
    validate that Azure AD can trust this web app

    This script will create the App Registrations that provide these configurations. Once those
    are created the configuration data will be saved to Azure App Configuration and the secret
    will be saved in Azure Key Vault so that the web app can read these values and provide them
    to Azure AD during the authentication process.

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

Param(
    [Alias("g")]
    [Parameter(Mandatory = $true, HelpMessage = "Name of the resource group that was created by azd")]
    [String]$ResourceGroupName,
    
    [Alias("sg")]
    [String]$SecondaryResourceGroupName
)

$canSetSecondAzureLocation=1

Write-Debug "Inputs"
Write-Debug "----------------------------------------------"
Write-Debug "resourceGroupName='$resourceGroupName'"
Write-Debug ""

$groupExists = (az group exists -n relecloudqa4-rg)
if ($groupExists -eq 'false') {
    Write-Error "FATAL ERROR: $ResourceGroupName could not be found in the current subscription"
    return
}
else {
    Write-Debug "Found resource group named: $ResourceGroupName"
}

$keyVaultName = (az keyvault list -g "$ResourceGroupName" --query "[? starts_with(name,'rc-')].name" -o tsv)
$appConfigSvcName = (az appconfig list -g "$ResourceGroupName" --query "[].name" -o tsv)


$appServiceRootUri='azurewebsites.net' # hard coded because app svc does not return the public endpoint
$frontEndWebAppName= (az resource list -g "$ResourceGroupName" --query "[? tags.\`"azd-service-name\`" == 'web' ].name" -o tsv)
$frontEndWebAppUri="https://$frontEndWebAppName.$appServiceRootUri"

$resourceToken = $frontEndWebAppName.substring(4, 13)
$environmentName = $ResourceGroupName.substring(0, $ResourceGroupName.Length - 3)

Write-Debug "Derived inputs"
Write-Debug "----------------------------------------------"
Write-Debug "keyVaultName=$keyVaultName"
Write-Debug "appConfigSvcName=$appConfigSvcName"
Write-Debug "frontEndWebAppUri=$frontEndWebAppUri"
Write-Debug "resourceToken=$resourceToken"
Write-Debug "environmentName=$environmentName"
Write-Debug ""

if ($keyVaultName.Length -eq 0) {
    Write-Error "FATAL ERROR: Could not find Key Vault resource. Confirm the --ResourceGroupName is the one created by the ``azd provision`` command."
    return
}

Write-Debug "Runtime values"
Write-Debug "----------------------------------------------"
$frontEndWebAppName = "$environmentName-$resourceToken-frontend"
$apiWebAppName = "$environmentName-$resourceToken-api"
$maxNumberOfRetries = 20

Write-Debug "frontEndWebAppName='$frontEndWebAppName'"
Write-Debug "apiWebAppName='$apiWebAppName'"
Write-Debug "maxNumberOfRetries=$maxNumberOfRetries"

$tenantId = (az account show --query "tenantId" -o tsv)
$userObjectId = (az account show --query "id" -o tsv)

Write-Debug "tenantId='$tenantId'"
Write-Debug ""

$frontEndWebObjectId = (az ad app list --filter "displayName eq '$frontEndWebAppName'" --query "[].id" -o tsv)


if ($frontEndWebObjectId.Length -eq 0) {

} else {
    Write-Host "frontend app registration objectId=$frontEndWebObjectId already exists. Delete the '$frontEndWebAppName' app registration to recreate or reset the settings."
    $frontEndWebAppClientId=$(az ad app show --id $frontEndWebObjectId --query "id" -o tsv)
    $canSetSecondAzureLocation=2
}