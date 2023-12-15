#Requires -Version 7.0

<#
.SYNOPSIS
    Validates that the user can access a Key Vault that will enable the sample to be deployed
.DESCRIPTION
    Configuring Azure AD B2C with 2 App Registrations is a pre-requisite for this sample.
    This script will validate that the pre-requisites have been completed correctly so that
    readers can ensure that their deployment will be successful.

.PARAMETER ResourceGroupName
    A required parameter for the name of the resource group that contains the key vault
    with the settings that were exported from Azure AD B2C.

.PARAMETER KeyVaultName
    A required parameter for the name of the Azure Key Vault that contains the key vault
    with the settings that were exported from Azure AD B2C.
#>

Param(
    [Alias("g")]
    [Parameter(Mandatory = $true)][string]
    $ResourceGroupName,
    
    [Alias("kv")]
    [Parameter(Mandatory = $true)][string]
    $KeyVaultName
)

$groupExists = (az group exists -g $ResourceGroupName)
if ($groupExists -eq 'false') {
    Write-Error "FATAL ERROR: $ResourceGroupName could not be found in the current subscription"
    exit 5
}

if ((az keyvault list --query "[? name=='$KeyVaultName'] | [0]").Length -eq 0) {
    Write-Error "FATAL ERROR: $KeyVaultName could not be found in the current subscription"
    exit 6
}

Write-Debug "`$ResourceGroupName = '$ResourceGroupName'"
Write-Debug "`$KeyVaultName = '$KeyVaultName'"

# confirm the secrets exist
$kvSecretNames = "frontEndAzureAdB2CApiScope",
                "frontEndAzureAdB2cClientId",
                "frontEndAzureAdB2cClientSecret",
                "apiAzureAdB2cClientId",
                "azureAdB2cDomain",
                "azureAdB2cInstance",
                "azureAdB2cTenantId",
                "azureAdB2cSignupSigninPolicyId",
                "azureAdB2cResetPolicyId",
                "azureAdB2cSignoutCallback"

$noErrors = $true

foreach ($kvSecretName in $kvSecretNames)
{
    Write-Debug "Checking settings for '$kvSecretName'"
    $secretName = (az keyvault secret list --vault-name $KeyVaultName --query "[? name=='$kvSecretName'].name | [0]")
    if ( $secretName.Length -eq 0) {
        Write-Error "Missing Key Vault setting: '$kvSecretName'. Please update your vault before trying the deployment"
        $noErrors = $false
    }
}

if ($noErrors) {
    Write-Host "Key Vault settings validated successfully. You are ready for the next step"
}