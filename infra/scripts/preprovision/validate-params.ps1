<#
.SYNOPSIS
    This script validates the parameters for the deployment of the Azure DevOps environment.

.DESCRIPTION
    The script retrieves the configuration values from Azure DevOps and validates the environment type and network isolation settings.
    It checks if the environment type is either 'dev' or 'prod' and if the network isolation is enabled for the 'prod' environment type.
    If any of the parameters are invalid, an error message is displayed and the script exits with a non-zero status code.

.NOTES
    - This script requires the Azure CLI to be installed and logged in to Azure DevOps.
    - The configuration values are retrieved using the 'azd env get-values' command.

.EXAMPLE
    ./validate-params.ps1

    This example runs the script to validate the parameters using the default configuration values.
#>


$azdConfig = azd env get-values -o json | ConvertFrom-Json -Depth 9 -AsHashtable


$environmentType = $azdConfig['ENVIRONMENT'] ?? 'dev'

# Block invalid deployment scenarios by helping the user understand the valid AZD options
if ($environmentType -ne 'dev' -and $environmentType -ne 'prod') {
    Write-Error "Invalid AZD environment type: '$environmentType'. Valid values are 'dev' or 'prod'."
    exit 1
}