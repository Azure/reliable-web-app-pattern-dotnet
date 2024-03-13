<#
.SYNOPSIS
    Cleans up the Azure resources for the Reliable Web App pattern for a given azd environment.
.DESCRIPTION
    There are times that azd down doesn't work well.  At time of writing, this includes complex
    environments with multiple resource groups and networking.  To remedy this, this script removes
    the Azure resources in the correct order.

    If you do not provide any parameters, this script will clean up the most current azd environment.
.PARAMETER Prefix
    The prefix of the Azure environment to clean up.  Provide this OR the ResourceGroup parameter to
    clean up a specific environment.
.PARAMETER ResourceGroup
    The name of the application resource group to clean up.  Provide this OR the Prefix parameter to clean
    up a specific environment.
.PARAMETER SpokeResourceGroup
    If you provide the ResourceGroup parameter and are using network isolation, then you must also provide
    the SpokeResourceGroup if it is a different resource group.  If you don't, then the spoke network will
    not be cleaned up.
.PARAMETER HubResourceGroup
    If you provide the ResourceGroup parameter and have deployed a hub network, then you must also provide
    the HubResourceGroup if it is a different resource group.  If you don't, then the hub network will not
    be cleaned up.
.PARAMETER DeleteGroups
    Defaults to true, but if you set this to false, then the resource groups will not be deleted.  This is
    expected behavior when combined with the `azd down` command which will take responsibility for deleting
    the resource groups.
.NOTES
    This command requires that Az modules are installed and imported. It also requires that you have an
    active Azure session.  If you are not authenticated with Azure, you will be prompted to authenticate.
#>

Param(
    [Parameter(Mandatory = $false)][string]$Prefix,
    [Parameter(Mandatory = $false)][string]$ResourceGroup,
    [Parameter(Mandatory = $false)][string]$SecondaryResourceGroup,
    [Parameter(Mandatory = $false)][string]$SpokeResourceGroup,
    [Parameter(Mandatory = $false)][string]$SecondarySpokeResourceGroup,
    [Parameter(Mandatory = $false)][string]$HubResourceGroup,
    [Parameter(Mandatory = $false)][switch]$SkipResourceGroupDeletion,
    [Parameter(Mandatory = $false)][switch]$Purge,
    [Parameter(Mandatory = $false)][switch]$NoPrompt
)


if ((Get-Module -ListAvailable -Name Az) -and (Get-Module -Name Az.Resources -ErrorAction SilentlyContinue)) {
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
        Write-Error "Failed to import the 'Az' module. Please install and import the 'Az' module before running this script."
        exit 12
    }
}

function Test-ResourceGroupExists($resourceGroupName) {
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    return $null -ne $resourceGroup
}

# Default Settings
$rgPrefix = ""
$rgApplication = ""
$rgSpoke = ""
$rgHub = ""
$rgSecondaryApplication = ""
$rgSecondarySpoke = ""
#$CleanupAzureDirectory = $false

$azdConfig = azd env get-values -o json | ConvertFrom-Json -Depth 9 -AsHashtable

if ($Prefix) {
    $rgPrefix = $Prefix
    $rgApplication = "$rgPrefix-application"
    $rgSpoke = "$rgPrefix-spoke"
    $rgSecondaryApplication = "$rgPrefix-2-application"
    $rgSecondarySpoke = "$rgPrefix-2-spoke"
    $rgHub = "$rgPrefix-hub"
} else {
    if (!$ResourceGroup) {
        if (!(Test-Path -Path ./.azure -PathType Container)) {
            "No .azure directory found and no resource group information provided - cannot clean up"
            exit 8
        }
        $environmentName = $azdConfig['AZURE_ENV_NAME']
        $environmentType = $azdConfig['AZURE_ENV_TYPE'] ?? 'dev'
        $location = $azdConfig['AZURE_LOCATION']
        $locationSecondary = $azdConfig['AZURE_LOCATION'] ?? $azdConfig['AZURE_LOCATION']
        $rgPrefix = "rg-$environmentName-$environmentType"
        $rgApplication = "$rgPrefix-$location-application"
        $rgSpoke = "$rgPrefix-$location-spoke"
        $rgSecondaryApplication = "$rgPrefix-$locationSecondary-2-application"
        Write-Host "Secondary Application Resource Group: $rgSecondaryApplication"
        $rgSecondarySpoke = "$rgPrefix-$locationSecondary-2-spoke"    
        Write-Host "Secondary Spoke Resource Group: $rgSecondarySpoke"
        $rgHub = "$rgPrefix-hub"
        #$CleanupAzureDirectory = $true
    } else {
        $rgApplication = $ResourceGroup
        if (Test-ResourceGroupExists -ResourceGroupName $rgApplication) {
            # Tags on the group describe the environment
            $rgResource = Get-AzResourceGroup -Name $rgApplication -ErrorAction SilentlyContinue
            $rgPrefix = $ResourceGroup.Substring(0, $ResourceGroup.IndexOf('-application') - $rgResource.Location.Length - 1)
            $location = $rgResource.Location
            $locationSecondary = $rgResource.Tags['SecondaryLocation'] ?? $rgResource.Location
        }
    }
}

if ($SecondaryResourceGroup) {
    $rgSecondaryApplication = $SecondaryResourceGroup
} elseif ($rgSecondaryApplication -eq '') {
    $rgSecondaryApplication = "$rgPrefix-$locationSecondary-2-application"
}
if ($SpokeResourceGroup) {
    $rgSpoke = $SpokeResourceGroup
} elseif ($rgSpoke -eq '') {
    $rgSpoke = "$rgPrefix-$location-spoke"
}
if ($SecondarySpokeResourceGroup) {
    $rgSecondarySpoke = $SecondarySpokeResourceGroup
} elseif ($rgSecondarySpoke -eq '') {
    $rgSecondarySpoke = "$rgPrefix-$locationSecondary-2-spoke"
}
if ($HubResourceGroup) {
    $rgHub = $HubResourceGroup
} elseif ($rgHub -eq '') {
    $rgHub = "$rgPrefix-$location-hub"
}

# Gets an access token for accessing Azure Resource Manager APIs
function Get-AzAccessToken {
    $azContext = Get-AzContext
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
    $token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
    return $token
}

# Get-AzConsumptionBudget doesn't seem to return the list of budgets,
# so we use the REST API instead.
function Get-AzBudget($resourceGroupName) {
    $azContext = Get-AzContext
    $token = Get-AzAccessToken
    $authHeader = @{
        'Content-Type'='application/json'
        'Authorization'='Bearer ' + $token.AccessToken
    }
    $baseUri = "https://management.azure.com/subscriptions/$($azContext.Subscription)/resourceGroups/$($resourceGroupName)/providers/Microsoft.Consumption/budgets"
    $apiVersion = "?api-version=2023-05-01"
    $restUri = "$($baseUri)$($apiVersion)"
    $result = Invoke-RestMethod -Uri $restUri -Method GET -Header $authHeader
    return $result.value
}

function Remove-ConsumptionBudgetForResourceGroup($resourceGroupName) {
    Get-AzBudget -ResourceGroupName $resourceGroupName
    | Foreach-Object {
        "`tRemoving $resourceGroupName::$($_.name)" | Write-Output
        Remove-AzConsumptionBudget -Name $_.name -ResourceGroupName $resourceGroupName
    }
}

function Remove-DiagnosticSettingsForResourceGroup($resourceGroupName) {
    Get-AzResource -ResourceGroupName $resourceGroupName
    | Foreach-Object {
        $resourceName = $_.Name
        $resourceId = $_.ResourceId
        Get-AzDiagnosticSetting -ResourceId $resourceId -ErrorAction SilentlyContinue | Foreach-Object {
            "`tRemoving $resourceGroupName::$resourceName::$($_.Name)" | Write-Output
            Remove-AzDiagnosticSetting -ResourceId $resourceId -Name $_.Name 
        }
    }
}

function Remove-PrivateEndpointsForResourceGroup($resourceGroupName) {
    Get-AzPrivateEndpoint -ResourceGroupName $resourceGroupName
    | Foreach-Object {
        "`tRemoving $resourceGroupName::$($_.Name)" | Write-Output
        Remove-AzPrivateEndpoint -Name $_.Name -ResourceGroupName $_.ResourceGroupName -Force
    }
}

function Remove-ResourceGroupFromAzure($resourceGroupName) {
    if (Test-ResourceGroupExists -ResourceGroupName $resourceGroupName) {
        "`tRemoving $resourceGroupName" | Write-Output
        Remove-AzResourceGroup -Name $resourceGroupName -Force
    }
}

function Test-EntraAppRegistrationExists($name) {
    $appRegistration = Get-AzADApplication -DisplayName $name -ErrorAction SilentlyContinue
    return $null -ne $appRegistration
}

function Remove-AzADApplicationByName($name) {
    $appRegistration = Get-AzADApplication -DisplayName $name -ErrorAction SilentlyContinue
    if ($appRegistration) {
        "`tRemoving $name" | Write-Output
        Remove-AzADApplication -ObjectId $appRegistration.Id
    }
}

function Get-ResourceToken($resourceGroupName) {
    $defaultRedisNamePrefix = 'redis-'
    $redisInstances = Get-AzRedisCache -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

    if ($redisInstances.Count -eq 0) {
        return "notfound"
    }

    return ($redisInstances | Select-Object -First 1).Name.Substring($defaultRedisNamePrefix.Length)
}

<#
.SYNOPSIS
    Reads input from the user, but taking care of default value and request to
    not prompt the user.
.PARAMETER Prompt
    The prompt to display to the user.
.PARAMETER DefaultValue
    The default value to use if the user just hits Enter.
.PARAMETER NoPrompt
    If specified, don't prompt - just use the default value.
#>
function Read-ApplicationPrompt {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Prompt,

        [Parameter(Mandatory = $true)]
        [string] $DefaultValue,

        [Parameter(Mandatory = $false)]
        [switch] $NoPrompt = $false
    )

    $returnValue = ""
    if (-not $NoPrompt) {
        $returnValue = Read-Host -Prompt "`n$($Prompt) [default: $(Get-HighlightedText($DefaultValue))] "
    }
    if ([string]::IsNullOrWhiteSpace($returnValue)) {
        $returnValue = $DefaultValue
    }
    return $returnValue
}
"`nCleaning up environment for application '$rgApplication'" | Write-Output

# Get the list of resource groups to deal with
$resourceGroups = [System.Collections.ArrayList]@()
if (Test-ResourceGroupExists -ResourceGroupName $rgApplication) {
    "`tFound application resource group: $rgApplication" | Write-Output
    $resourceGroups.Add($rgApplication) | Out-Null
} else {
    "`tConfirm the correct subscription was selected and check the spelling of the group to be deleted" | Write-Warning
    "`tCould not find resource group: $rgApplication" | Write-Error
    exit 9
}
if (Test-ResourceGroupExists -ResourceGroupName $rgSecondaryApplication) {
    "`tFound secondary application resource group: $rgSecondaryApplication" | Write-Output
    $resourceGroups.Add($rgSecondaryApplication) | Out-Null
}


if (Test-ResourceGroupExists -ResourceGroupName $rgSpoke) {
    "`tFound spoke resource group: $rgSpoke" | Write-Output
    $resourceGroups.Add($rgSpoke) | Out-Null
}
if (Test-ResourceGroupExists -ResourceGroupName $rgSecondarySpoke) {
    "`tFound secondary spoke resource group: $rgSecondarySpoke" | Write-Output
    $resourceGroups.Add($rgSecondarySpoke) | Out-Null
}
if (Test-ResourceGroupExists -ResourceGroupName $rgHub) {
    "`tFound hub resource group: $rgHub" | Write-Output
    $resourceGroups.Add($rgHub) | Out-Null
}

$resourceToken=(Get-ResourceToken -resourceGroupName $rgApplication) # expecting to be something like 'fjmjdbizcdxt4'
$appRegistrations = [System.Collections.ArrayList]@()
$calculatedAppRegistrationNameForApi = "$rgPrefix-api-webapp-$resourceToken".Substring(3)
$calculatedAppRegistrationNameForFrontend = "$rgPrefix-front-webapp-$resourceToken".Substring(3)

if (Test-EntraAppRegistrationExists -Name $calculatedAppRegistrationNameForApi) {
    "`tFound Entra ID App Registration: $calculatedAppRegistrationNameForApi" | Write-Output
    $appRegistrations.Add($calculatedAppRegistrationNameForApi) | Out-Null
}
if (Test-EntraAppRegistrationExists -Name $calculatedAppRegistrationNameForFrontend) {
    "`tFound Entra ID App Registration: $calculatedAppRegistrationNameForFrontend" | Write-Output
    $appRegistrations.Add($calculatedAppRegistrationNameForFrontend) | Out-Null
}

# Determine if we need to purge the App Configuration and Key Vault.
$defaultPurgeResources = if ($Purge) { "y" } else { "n" }
$purgeResources = Read-ApplicationPrompt -Prompt "Do you wish to puge resources that cannot be reassigned immediately (such as Key Vault)? [y/n]" -DefaultValue $defaultPurgeResources -NoPrompt:$NoPrompt

# press enter to proceed
if (-not $NoPrompt) {
    "`nPress enter to proceed with cleanup or CTRL+C to cancel" | Write-Output
    $null = Read-Host
}

# we don't want to delete the app registrations because we reuse them when running in pipeline
# when running in pipeline, the AZURE_PRINCIPAL_TYPE is set to 'ServicePrincipal'
if ($azdConfig['AZURE_PRINCIPAL_TYPE'] -eq 'User') {    
    "`nRemoving Entra ID App Registration..." | Write-Output
    foreach($appRegistration in $appRegistrations) {
        Remove-AzADApplicationByName -Name $appRegistration
    }
}

if ($purgeResources -eq "y") {
    "> Remove and purge purgeable resources:" | Write-Output
    foreach ($resourceGroupName in $resourceGroups) {
        Get-AzKeyVault -ResourceGroupName $resourceGroupName | Foreach-Object {
            "`tRemoving $($_.VaultName)" | Write-Output
            Remove-AzKeyVault -VaultName $_.VaultName -ResourceGroupName $resourceGroupName -Force
            "`tPurging $($_.VaultName)" | Write-Output
            Remove-AzKeyVault -VaultName $_.VaultName -Location $_.Location -InRemovedState -Force -ErrorAction SilentlyContinue
        }

        Get-AzAppConfigurationStore -ResourceGroupName $resourceGroupName | Foreach-Object {
            "`tRemoving $($_.Name)" | Write-Output
            Remove-AzAppConfigurationStore -Name $_.Name -ResourceGroupName $resourceGroupName
            "`tPurging $($_.Name)" | Write-Output
            Clear-AzAppConfigurationDeletedStore -Location $_.Location -Name $_.Name -ErrorAction SilentlyContinue
        }
    }
}

"`nRemoving resources from resource groups..." | Write-Output
"> Private Endpoints:" | Write-Output
foreach ($resourceGroupName in $resourceGroups) {
    Remove-PrivateEndpointsForResourceGroup -ResourceGroupName $resourceGroupName
}

"> Budgets:" | Write-Output
foreach ($resourceGroupName in $resourceGroups) {
    Remove-ConsumptionBudgetForResourceGroup -ResourceGroupName $resourceGroupName
}

"> Diagnostic Settings:" | Write-Output
foreach ($resourceGroupName in $resourceGroups) {
    Remove-DiagnosticSettingsForResourceGroup -ResourceGroupName $resourceGroupName
}

# if $SkipResourceGroupDeletion is false, then we skip the resource group deletion
# flag is expected to be set to false when combined with the `azd down` command
if (-not $SkipResourceGroupDeletion) {
    "`nRemoving resource groups in order..." | Write-Output
    Remove-ResourceGroupFromAzure -ResourceGroupName $rgApplication
    Remove-ResourceGroupFromAzure -ResourceGroupName $rgSecondaryApplication
    Remove-ResourceGroupFromAzure -ResourceGroupName $rgSpoke
    Remove-ResourceGroupFromAzure -ResourceGroupName $rgSecondarySpoke
    Remove-ResourceGroupFromAzure -ResourceGroupName $rgHub
    
    "`nCleanup complete." | Write-Output
}