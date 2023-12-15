<#
.SYNOPSIS
    This script will be run by the Azure Developer CLI, and will have access to the AZD_* vars
    This ensures the the app configuration service is reachable from the current environment.

.DESCRIPTION
    This script will be run by the Azure Developer CLI, and will set the required
    app configuration settings for the Relecloud web app as part of the code deployment process.

    Depends on the AZURE_RESOURCE_GROUP environment variable being set. AZD requires this to
    understand which resource group to deploy to so this script uses it to learn about the
    environment where the configuration settings should be set.

#>

$resourceGroupName = ((azd env get-values --output json) | ConvertFrom-Json).AZURE_RESOURCE_GROUP

Write-Host "Calling set-app-configuration.ps1 for group:'$resourceGroupName'..."

./infra/scripts/predeploy/set-app-configuration.ps1 -ResourceGroupName $resourceGroupName -NoPrompt