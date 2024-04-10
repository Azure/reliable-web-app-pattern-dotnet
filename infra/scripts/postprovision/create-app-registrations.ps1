<#
.SYNOPSIS
    Creates Microsoft Entra ID App Registrations for the call center web and api applications
    and saves the configuration data in App Configuration Svc and Key Vault.
        Depends on Az module.

    <This command should only be run after using the azd command to deploy resources to Azure>
    
.DESCRIPTION
    The web app uses Microsoft Entra ID to authenticate and authorize the users that can
    make concert ticket purchases. This script configures the required settings and saves them in Key Vault.
    The following settings are configured:

        Api--MicrosoftEntraId--ClientId              Identifies the web app to Microsoft Entra ID
        Api--MicrosoftEntraId--TenantId              Identifies which Microsoft Entra ID instance holds the users that should be authorized
        MicrosoftEntraId--CallbackPath               The path that Microsoft Entra ID should redirect to after a successful login
        MicrosoftEntraId--ClientId                   Identifies the web app to Microsoft Entra ID
        MicrosoftEntraId--ClientSecret               Provides a secret known by Microsoft Entra ID, and shared with the web app, to validate that Microsoft Entra ID can trust this web app
        MicrosoftEntraId--Instance                   Identifies which Microsoft Entra ID instance holds the users that should be authorized
        MicrosoftEntraId--SignedOutCallbackPath      The path that Microsoft Entra ID should redirect to after a successful logout
        MicrosoftEntraId--TenantId                   Identifies which Microsoft Entra ID instance holds the users that should be authorized

    This script will create the App Registrations that provide these configurations. Once those
    are created the configuration data will be saved to Azure App Configuration and the secret
    will be saved in Azure Key Vault so that the web app can read these values and provide them
    to Microsoft Entra ID during the authentication process.

    NOTE: This functionality assumes that the web app, app configuration service, and app
    service have already been successfully deployed.

.PARAMETER ResourceGroupName
    A required parameter for the name of resource group that contains the environment that was
    created by the azd command. The cmdlet will populate the App Config Svc and Key
    Vault services in this resource group with Microsoft Entra ID app registration config data.
    
.EXAMPLE
    PS C:\> .\create-app-registrations.ps1 -ResourceGroupName rg-rele231127v4-dev-westus3-application

    This example will create the app registrations for the rele231127v4 environment.
#>

Param(
    [Alias("g")]
    [Parameter(Mandatory = $true, HelpMessage = "Name of the application resource group that was created by azd")]
    [String]$ResourceGroupName,
    [Parameter(Mandatory = $false, HelpMessage = "Use default values for all prompts")]
    [Switch]$NoPrompt
)

$MAX_RETRY_ATTEMPTS = 10
$API_SCOPE_NAME = "relecloud.api"

# Prompt formatting features

$defaultColor = if ($Host.UI.SupportsVirtualTerminal) { "`e[0m" } else { "" }
$successColor = if ($Host.UI.SupportsVirtualTerminal) { "`e[32m" } else { "" }
$highlightColor = if ($Host.UI.SupportsVirtualTerminal) { "`e[36m" } else { "" }

# End of Prompt formatting features

# Function definitions

function Get-CachedResourceGroup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )

    if ($global:resourceGroups -and $global:resourceGroups.ContainsKey($ResourceGroupName)) {
        return $global:resourceGroups[$ResourceGroupName]
    }

    $resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

    if (!$global:resourceGroups) {
        $global:resourceGroups = @{}
    }

    $global:resourceGroups[$ResourceGroupName] = $resourceGroup

    return $resourceGroup
}

function Get-WorkloadName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )

    $resourceGroup = Get-CachedResourceGroup -ResourceGroupName $ResourceGroupName
    # Something like 'rele231116v1'
    return $resourceGroup.Tags["WorkloadName"]
}

function Get-WorkloadResourceToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    $resourceGroup = Get-CachedResourceGroup -ResourceGroupName $ResourceGroupName
    # Something like 'c2auhsbjt6h6i'
    return $resourceGroup.Tags["ResourceToken"]
}

function Get-WorkloadEnvironment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    $resourceGroup = Get-CachedResourceGroup -ResourceGroupName $ResourceGroupName
    # Something like 'dev', 'test', 'prod'
    return $resourceGroup.Tags["Environment"]
}

function Get-ApiAppRegistration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppRegistrationName,
        [Parameter(Mandatory = $true)]
        [string]$ExistingAppRegistrationId
    )
    
    # get an existing Front-end App Registration
    $apiAppRegistration = Get-AzADApplication -DisplayName $AppRegistrationName -ErrorAction SilentlyContinue

    # if it doesn't exist, then return a new one we created
    if (!$apiAppRegistration) {
        Write-Host "`tCreating the API registration $highlightColor'$($AppRegistrationName)'$defaultColor" 

        return New-ApiAppRegistration `
            -AppRegistrationName $AppRegistrationName -ExistingAppRegistrationId $ExistingAppRegistrationId
    }

    Write-Host "`tRetrieved the existing API registration $highlightColor'$($apiAppRegistration.Id)'$defaultColor"
    return $apiAppRegistration
}

function New-ApiAppRegistration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppRegistrationName,
        [Parameter(Mandatory = $true)]
        [string]$ExistingAppRegistrationId
    )

    $delegatedPermissionId = (New-Guid).ToString()

    # Define the OAuth2 permissions (scopes) for the API
    # https://learn.microsoft.com/en-us/dotnet/api/microsoft.azure.powershell.cmdlets.resources.msgraph.models.apiv10.imicrosoftgraphapiapplication?view=az-ps-latest
    # typing is case sensitive on the following objects and properites
    $apiPermissions = [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphApiApplication]@{
        Oauth2PermissionScope = [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphPermissionScope[]]@(
            [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphPermissionScope ]@{
                Id = $delegatedPermissionId
                Type = "User"
                AdminConsentDescription = "Allow the app to access the web API as a user"
                AdminConsentDisplayName = "Access the web API"
                IsEnabled = $true
                Value = $API_SCOPE_NAME
                UserConsentDescription = "Allow the app to access the web API on your behalf"
                UserConsentDisplayName = "Access the web API"
            })
        PreAuthorizedApplication = [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphPreAuthorizedApplication[]]@(
            [Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.IMicrosoftGraphPreAuthorizedApplication]@{
                AppId = $ExistingAppRegistrationId
                DelegatedPermissionId = @($delegatedPermissionId)
            }
        )
    }
    
    # log the API permissions to console for debugging
    #Write-Host "`t`tAPI Permissions:"
    #Write-Host "`t`t`t$($apiPermissions | ConvertTo-Json -Depth 100)"

    # create a Microsoft Entra ID App Registration for the front-end web app
    $apiAppRegistration = New-AzADApplication `
        -DisplayName $AppRegistrationName `
        -SignInAudience "AzureADMyOrg" `
        -Api $apiPermissions `
        -ErrorAction Stop

    # set the identifier URI to the app ID (this is the default behavior)
    $apiAppRegistration.IdentifierUri = @("api://$($apiAppRegistration.AppId)")

    # save the change
    Update-AzADApplication -ObjectId $apiAppRegistration.Id -IdentifierUris $apiAppRegistration.IdentifierUri

    # $clientId = ""
    # while ($clientId -eq "" -and $attempts -lt $MAX_RETRY_ATTEMPTS)
    # {
    #     $MAX_RETRY_ATTEMPTS = $MAX_RETRY_ATTEMPTS + 1
    #     try {
    #         $clientId = (Get-AzADApplication -DisplayName $AppRegistrationName -ErrorAction Stop).ApplicationId
    #     }
    #     catch {
    #         Write-Host "`t`tFailed to retrieve the client ID for the front-end app registration. Will try again in 3 seconds."
    #         Start-Sleep -Seconds 3
    #     }
    # }

    return $apiAppRegistration
}

function Get-FrontendAppRegistration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppRegistrationName,
        [Parameter(Mandatory = $true)]
        [string]$AzureWebsiteRedirectUri,
        [Parameter(Mandatory = $true)]
        [string]$AzureWebsiteLogoutUri,
        [Parameter(Mandatory = $true)]
        [string]$LocalhostWebsiteRedirectUri
    )
    
    # get an existing Front-end App Registration
    $frontendAppRegistration = Get-AzADApplication -DisplayName $AppRegistrationName -ErrorAction SilentlyContinue

    # if it doesn't exist, then return a new one we created
    if (!$frontendAppRegistration) {
        Write-Host "`tCreating the front-end app registration $highlightColor'$($AppRegistrationName)'$defaultColor"    

        return New-FrontendAppRegistration `
            -AzureWebsiteRedirectUri $AzureWebsiteRedirectUri `
            -AzureWebsiteLogoutUri $AzureWebsiteLogoutUri `
            -LocalhostWebsiteRedirectUri $LocalhostWebsiteRedirectUri `
            -AppRegistrationName $AppRegistrationName
    }

    Write-Host "`tRetrieved the existing front-end app registration $highlightColor'$($frontendAppRegistration.Id)'$defaultColor"
    return $frontendAppRegistration
}

function New-FrontendAppRegistration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppRegistrationName,
        [Parameter(Mandatory = $true)]
        [string]$AzureWebsiteRedirectUri,
        [Parameter(Mandatory = $true)]
        [string]$AzureWebsiteLogoutUri,
        [Parameter(Mandatory = $true)]
        [string]$LocalhostWebsiteRedirectUri
    )
    $websiteApp = @{
        "LogoutUrl" = $AzureWebsiteLogoutUri
        "RedirectUris" = @($AzureWebsiteRedirectUri, $LocalhostWebsiteRedirectUri)
        "ImplicitGrantSetting" = @{
            "EnableAccessTokenIssuance" = $false
            "EnableIdTokenIssuance" = $true
        }
    }

    # create a Microsoft Entra ID App Registration for the front-end web app
    $frontendAppRegistration = New-AzADApplication `
        -DisplayName $AppRegistrationName `
        -SignInAudience "AzureADMyOrg" `
        -Web $websiteApp `
        -ErrorAction Stop

    # $clientId = ""
    # while ($clientId -eq "" -and $attempts -lt $MAX_RETRY_ATTEMPTS)
    # {
    #     $MAX_RETRY_ATTEMPTS = $MAX_RETRY_ATTEMPTS + 1
    #     try {
    #         $clientId = (Get-AzADApplication -DisplayName $AppRegistrationName -ErrorAction Stop).ApplicationId
    #     }
    #     catch {
    #         Write-Host "`t`tFailed to retrieve the client ID for the front-end app registration. Will try again in 3 seconds."
    #         Start-Sleep -Seconds 3
    #     }
    # }

    return $frontendAppRegistration
}

# End of function definitions


# Check for required features

if ((Get-Module -ListAvailable -Name Az.Resources) -and (Get-Module -Name Az.Resources -ErrorAction SilentlyContinue)) {
    Write-Debug "The 'Az.Resources' module is installed and imported."
    if (Get-AzContext -ErrorAction SilentlyContinue) {
        Write-Debug "The user is authenticated with Azure."
    }
    else {
        Write-Error "You are not authenticated with Azure. Please run 'Connect-AzAccount' to authenticate before running this script."
        exit 10
    }
}
else {
    try {
        Write-Host "Importing 'Az.Resources' module"
        Import-Module -Name Az.Resources -ErrorAction Stop
        Write-Debug "The 'Az.Resources' module is imported successfully."
        if (Get-AzContext -ErrorAction SilentlyContinue) {
            Write-Debug "The user is authenticated with Azure."
        }
        else {
            Write-Error "You are not authenticated with Azure. Please run 'Connect-AzAccount' to authenticate before running this script."
            exit 11
        }
    }
    catch {
        Write-Error "Failed to import the 'Az.Resources' module. Please install and import the 'Az' module before running this script."
        exit 12
    }
}

# End of feature checking

# Set defaults
$defaultFrontEndAppRegistrationName = "$(Get-WorkloadName -ResourceGroupName $ResourceGroupName)-$(Get-WorkloadEnvironment -ResourceGroupName $ResourceGroupName)-front-webapp-$(Get-WorkloadResourceToken -ResourceGroupName $ResourceGroupName)"
$defaultApiAppRegistrationName = "$(Get-WorkloadName -ResourceGroupName $ResourceGroupName)-$(Get-WorkloadEnvironment -ResourceGroupName $ResourceGroupName)-api-webapp-$(Get-WorkloadResourceToken -ResourceGroupName $ResourceGroupName)"
$defaultKeyVaultname = "kv-$(Get-WorkloadResourceToken -ResourceGroupName $ResourceGroupName)"

$frontDoorProfile = (Get-AzFrontDoorCdnProfile -ResourceGroupName $ResourceGroupName)
$frontDoorEndpoint = (Get-AzFrontDoorCdnEndpoint -ProfileName $frontDoorProfile.Name -ResourceGroupName $ResourceGroupName)
$defaultAzureWebsiteUri = "https://$($frontDoorEndpoint.HostName)"

# End of Set defaults

# Gather inputs

# The web app has two websites so we need to create two app registrations.
# This app registration is for the back-end API that the front-end website will call.
$apiAppRegistrationName = ""
if (-not $NoPrompt) {
    $apiAppRegistrationName = Read-Host -Prompt "`nWhat should the name of the API web app registration be? [default: $highlightColor$defaultApiAppRegistrationName$defaultColor]"
}

if ($apiAppRegistrationName -eq "") {
    $apiAppRegistrationName = $defaultApiAppRegistrationName
}

# This app registration is for the front-end website that users will interact with.
$frontendAppRegistrationName = ""
if (-not $NoPrompt) {
    $frontendAppRegistrationName = Read-Host -Prompt "`nWhat should the name of the Front-end web app registration be? [default: $highlightColor$defaultFrontEndAppRegistrationName$defaultColor]"
}

if ($frontendAppRegistrationName -eq "") {
    $frontendAppRegistrationName = $defaultFrontEndAppRegistrationName
}

# This is where the App Registration details will be stored
$keyVaultName = ""
if (-not $NoPrompt) {
    $keyVaultName = Read-Host -Prompt "`nWhat is the name of the Key Vault that should store the App Registration details? [default: $highlightColor$defaultKeyVaultname$defaultColor]"
}

if ($keyVaultName -eq "") {
    $keyVaultName = $defaultKeyVaultname
}

$azureWebsiteUri = ""
if (-not $NoPrompt) {
    $azureWebsiteUri = Read-Host -Prompt "`nWhat is the login redirect uri of the website? [default: $highlightColor$defaultAzureWebsiteUri$defaultColor]"
}

if ($azureWebsiteUri -eq "") {
    $azureWebsiteUri = $defaultAzureWebsiteUri
}

$tenantId = (Get-AzContext).Tenant.Id

# hard coded localhost URL comes from startup properties of the web app
$localhostWebsiteRedirectUri = "https://localhost:7227/signin-oidc"
$azureWebsiteRedirectUri = "$azureWebsiteUri/signin-oidc"
$azureWebsiteLogoutUri = "$azureWebsiteUri/signout-oidc"

# End of Gather inputs

# Display working state for confirmation
Write-Host "`nSetup for App Registrations" -ForegroundColor Yellow
Write-Host "`ttenantId='$tenantId'"
Write-Host "`tresourceGroupName='$resourceGroupName'"
Write-Host "`tfrontendAppRegistrationName='$frontendAppRegistrationName'"
Write-Host "`tkeyVaultName='$keyVaultName'"
Write-Host "`tlocalhostWebsiteRedirectUri='$localhostWebsiteRedirectUri'"
Write-Host "`tazureWebsiteRedirectUri='$azureWebsiteRedirectUri'"
Write-Host "`tazureWebsiteLogoutUri='$azureWebsiteLogoutUri'"
Write-Host "`tapiAppRegistrationName='$apiAppRegistrationName'"

$confirmation = ""
if (-not $NoPrompt) {
    $confirmation = Read-Host -Prompt "`nHit enter proceed with creating app registrations"
}

if ($confirmation -ne "") {
    Write-Host "`nExiting without creating app registrations."
    exit 13
}

# End of Display working state for confirmation

# Test the existence of the Key Vault
$keyVault = Get-AzKeyVault -VaultName $keyVaultName -ErrorAction SilentlyContinue

if (!$keyVault) {
    Write-Error "The Key Vault '$keyVaultName' does not exist. Please create the Key Vault before running this script."
    exit 14
}

# Test to see if the current user has permissions to create secrets in the Key Vault
try {
    $secretValue = ConvertTo-SecureString -String 'https://login.microsoftonline.com/' -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'MicrosoftEntraId--Instance' -SecretValue $secretValue -ErrorAction Stop > $null
} catch {
    Write-Error "Unable to save data to '$keyVaultName'. Please check your permissions and the network restrictions on the Key Vault."
    exit 15
}

# Set static values
$secretValue = ConvertTo-SecureString -String '/signin-oidc' -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'MicrosoftEntraId--CallbackPath' -SecretValue $secretValue -ErrorAction Stop > $null
Write-Host "`tSaved the $highlightColor'MicrosoftEntraId--CallbackPath'$defaultColor to Key Vault"

$secretValue = ConvertTo-SecureString -String '/signout-oidc' -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'MicrosoftEntraId--SignedOutCallbackPath' -SecretValue $secretValue -ErrorAction Stop > $null
Write-Host "`tSaved the $highlightColor'MicrosoftEntraId--SignedOutCallbackPath'$defaultColor to Key Vault"

$secretInstance = ConvertTo-SecureString -String 'https://login.microsoftonline.com/' -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'Api--MicrosoftEntraId--Instance' -SecretValue $secretInstance -ErrorAction Stop > $null
Write-Host "`tSaved the $highlightColor'Api--MicrosoftEntraId--Instance'$defaultColor to Key Vault"

Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'MicrosoftEntraId--Instance' -SecretValue $secretInstance -ErrorAction Stop > $null
Write-Host "`tSaved the $highlightColor'MicrosoftEntraId--Instance'$defaultColor to Key Vault"

# Write TenantId to Key Vault
$secretValue = ConvertTo-SecureString -String $tenantId -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'Api--MicrosoftEntraId--TenantId' -SecretValue $secretValue -ErrorAction Stop > $null
Write-Host "`tSaved the $highlightColor'Api--MicrosoftEntraId--TenantId'$defaultColor to Key Vault"

$secretValue = ConvertTo-SecureString -String $tenantId -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'MicrosoftEntraId--TenantId' -SecretValue $secretValue -ErrorAction Stop > $null
Write-Host "`tSaved the $highlightColor'MicrosoftEntraId--TenantId'$defaultColor to Key Vault"

# Get or Create the front-end app registration
$frontendAppRegistration = Get-FrontendAppRegistration `
    -AzureWebsiteRedirectUri $azureWebsiteRedirectUri `
    -AzureWebsiteLogoutUri $azureWebsiteLogoutUri `
    -LocalhostWebsiteRedirectUri $localhostWebsiteRedirectUri `
    -AppRegistrationName $frontendAppRegistrationName

# Write to Key Vault
$secretValue = ConvertTo-SecureString -String $frontendAppRegistration.AppId -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'MicrosoftEntraId--ClientId' -SecretValue $secretValue -ErrorAction Stop > $null
Write-Host "`tSaved the $highlightColor'MicrosoftEntraId--ClientId'$defaultColor to Key Vault"

# List client secrets
$clientSecrets = Get-AzADAppCredential -ObjectId $frontendAppRegistration.Id -ErrorAction SilentlyContinue
# If there are secrets, then delete them
if ($clientSecrets) {
    # for each client secret
    foreach ($clientSecret in $clientSecrets) {
        # delete the client secret
        Remove-AzADAppCredential -ObjectId $frontendAppRegistration.Id -KeyId $clientSecret.KeyId -ErrorAction Stop > $null
    }
}

# Create a new client secret with a 1 year expiration
$clientSecrets = New-AzADAppCredential -ObjectId $frontendAppRegistration.Id -EndDate (Get-Date).AddYears(1) -ErrorAction Stop

# Write to Key Vault
$secretValue = ConvertTo-SecureString -String $clientSecrets.SecretText -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'MicrosoftEntraId--ClientSecret' -SecretValue $secretValue -ErrorAction Stop > $null
Write-Host "`tSaved the $highlightColor'MicrosoftEntraId--ClientSecret'$defaultColor to Key Vault"

# Get or Create the api app registration
$apiAppRegistration = Get-ApiAppRegistration `
    -AppRegistrationName $apiAppRegistrationName `
    -ExistingAppRegistrationId $frontendAppRegistration.AppId

# Write to Key Vault
$secretValue = ConvertTo-SecureString -String $apiAppRegistration.AppId -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'Api--MicrosoftEntraId--ClientId' -SecretValue $secretValue -ErrorAction Stop > $null
Write-Host "`tSaved the $highlightColor'Api--MicrosoftEntraId--ClientId'$defaultColor to Key Vault"

$scopeDetails = $apiAppRegistration.Api.Oauth2PermissionScope | Where-Object { $_.Value -eq $API_SCOPE_NAME }
if (!$scopeDetails) {
    Write-Error "Unable to find the scope '$API_SCOPE_NAME' in the API app registration. Please check the API app registration in Microsoft Entra ID."
    exit 16
}

Write-Host "`tFound the scope $highlightColor'$($scopeDetails.Value)'$defaultColor with ID $highlightColor'$($scopeDetails.Id)'$defaultColor"

# Check permission for front-end app registration to verify it has access to the API app registration
$apiPermission = Get-AzADAppPermission -ObjectId $frontendAppRegistration.Id -ErrorAction SilentlyContinue | Where-Object { $_.ApiId -eq $apiAppRegistration.AppId -and $_.Type -eq 'Scope' }
if (!$apiPermission) {
    Write-Host "`tCreating the permission for the front-end app registration to access the API app registration"
    $apiPermission = Add-AzADAppPermission -ObjectId $frontendAppRegistration.Id -ApiId $apiAppRegistration.AppId -PermissionId $scopeDetails.Id -ErrorAction Stop
}

$formattedScope = "$($apiAppRegistration.IdentifierUri)/$($scopeDetails.Value)"
$secretValue = ConvertTo-SecureString -String $formattedScope -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name 'App--RelecloudApi--AttendeeScope' -SecretValue $secretValue -ErrorAction Stop > $null
Write-Host "`tSaved the $highlightColor'App--RelecloudApi--AttendeeScope'$defaultColor to Key Vault"

Write-Host "`nFinished create-app-registrations $($successColor)successfully$($defaultColor)."

# all done
exit 0