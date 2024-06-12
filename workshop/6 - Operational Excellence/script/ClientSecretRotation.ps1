<#
.SYNOPSIS
Regenerates the client secret for an Azure AD app registration and saves it in a Key Vault. Then restarts an Azure App Service.

.DESCRIPTION
This PowerShell script shows a secret rotation strategy for the Reliable Web App Pattern. It assumes the RWA has been deployed and uses the existing key vault and app configuration service to retrieve configuration values. It regenerates the client secret for the specified Azure AD app registration, saves it in the specified Key Vault, and then restarts the specified Azure App Service.

.PARAMETER ResourceGroupName
The name of the resource group containing the App Service.

.EXAMPLE
.\ClientSecretRotation.ps1 -ResourceGroupName

This example regenerates the client secret for the Azure AD app registration with the specified Client ID, saves it in the Key Vault with the specified name, and then restarts the Azure App Service with the specified name.

.NOTES
This script requires the Azure CLI to be installed.

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName
)

# Checking for existing Resource group
$resourceGroupExists= (az group list --query "[?contains(name, '$ResourceGroupName')].name" -o tsv)
if ($null -eq $resourceGroupExists) {
    Write-Error "Resource group $ResourceGroupName does not exist."
    exit
}

# Find the key vault in this resource group
$KeyVaultName = (az keyvault list -g "$ResourceGroupName" --query "[? starts_with(name,'rc-')].name" -o tsv)
Write-Host "Found the key vault: $KeyVaultName"

# Find the App Configuration Service in this resource group
$AppConfigServiceName = (az appconfig list -g $ResourceGroupName --query '[].name | [0]' -o tsv)
Write-Host "Found the App Configuration Service: $AppConfigServiceName"

# Checking for existing App Service
$AppServiceName = (az resource list -g "$ResourceGroupName" --query "[? tags.\`"azd-service-name\`" == 'web' ].name | [0]" -o tsv)
Write-Host "Found the App Service: $AppServiceName"

#  "Checking for existing app registration..."
$ClientId = (az appconfig kv show --name $AppConfigServiceName --key 'AzureAd:ClientId' --query 'value' -o tsv)
Write-Host "Found the ClientId: $ClientId"

# Reset the client secret
$reliableWebAppSecret= (az ad app credential reset --id $ClientId --append --query "password" --display-name "Script Generated")

Write-Host "New client secret has been generated in Azure AD."

# Get the Key Vault and add the secret
az keyvault secret set --vault-name $KeyVaultName --name "AzureAd--ClientSecret" --value $reliableWebAppSecret
Write-Host "New client secret has been saved to Key Vault."

# Restart the App Service
az webapp restart --name $AppServiceName --resource-group $ResourceGroupName
Write-Host "Front-end web app is restarting... please allow 30-60 seconds for this operation to complete."