<#
.SYNOPSIS
    This script will be run by the Azure Developer CLI, and will have access to the AZD_* vars
    This calls the create app registration.ps1 with the correct AZD provisioned resource group.

.DESCRIPTION
    This script will be run by the Azure Developer CLI, and will set the required
    app configuration settings for the Relecloud web app as part of the code deployment process.

    Depends on the AZURE_RESOURCE_GROUP environment variable being set. AZD requires this to
    understand which resource group to deploy to so this script uses it to learn about the
    environment where the configuration settings should be set.

#>

# if this is CI/CD then we want to skip this step because the app registrations already exist
$principalType = (azd env get-values --output json | ConvertFrom-Json).AZURE_PRINCIPAL_TYPE

if ($principalType -eq "ServicePrincipal") {
    Write-Host "Skipping create-app-registrations.ps1 because principalType is ServicePrincipal"
    exit 0
}

$resourceGroupName=(azd env get-values --output json | ConvertFrom-Json).AZURE_RESOURCE_GROUP

Write-Host "Calling create-app-registrations.ps1 for group:'$resourceGroupName'..."

./infra/scripts/postprovision/create-app-registrations.ps1 -ResourceGroupName $resourceGroupName -NoPrompt