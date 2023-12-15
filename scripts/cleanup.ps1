<#
.SYNOPSIS
    Cleans up the Azure resources for the Field Engineer application for a given azd environment.
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
    [Parameter(Mandatory = $false)][string]$HubResourceGroup
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

# Default Settings
$rgPrefix = ""
$rgApplication = ""
$rgSpoke = ""
$rgHub = ""
$rgSecondaryApplication = ""
$rgSecondarySpoke = ""
#$CleanupAzureDirectory = $false

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
        $azdConfig = azd env get-values -o json | ConvertFrom-Json -Depth 9 -AsHashtable
        $environmentName = $azdConfig['AZURE_ENV_NAME']
        $environmentType = $azdConfig['AZURE_ENV_TYPE'] ?? 'dev'
        $location = $azdConfig['AZURE_LOCATION']
        $rgPrefix = "rg-$environmentName-$environmentType-$location"
        $rgApplication = "$rgPrefix-application"
        $rgSpoke = "$rgPrefix-spoke"
        $rgSecondaryApplication = "$rgPrefix-2-application"
        $rgSecondarySpoke = "$rgPrefix-2-spoke"    
        $rgHub = "$rgPrefix-hub"
        #$CleanupAzureDirectory = $true
    } else {
        $rgApplication = $ResourceGroup
        $rgPrefix = $resourceGroup.Substring(0, $resourceGroup.IndexOf('-application'))
    }
}

if ($SecondaryResourceGroup) {
    $rgSecondaryApplication = $SecondaryResourceGroup
} elseif ($rgSecondaryApplication -eq '') {
    $rgSecondaryApplication = "$rgPrefix-2-application"
}
if ($SpokeResourceGroup) {
    $rgSpoke = $SpokeResourceGroup
} elseif ($rgSpoke -eq '') {
    $rgSpoke = "$rgPrefix-spoke"
}
if ($SecondarySpokeResourceGroup) {
    $rgSecondarySpoke = $SecondarySpokeResourceGroup
} elseif ($rgSecondarySpoke -eq '') {
    $rgSecondarySpoke = "$rgPrefix-2-spoke"
}
if ($HubResourceGroup) {
    $rgHub = $HubResourceGroup
} elseif ($rgHub -eq '') {
    $rgHub = "$rgPrefix-hub"
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

function Test-ResourceGroupExists($resourceGroupName) {
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    return $null -ne $resourceGroup
}

# Removed all budgets that are scoped to a resource group of interest.
function Remove-ConsumptionBudgetForResourceGroup($resourceGroupName) {
    # Get-AzConsumptionBudget -ResourceGroupName $resourceGroupName
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

# press enter to proceed
"`nPress enter to proceed with cleanup or CTRL+C to cancel" | Write-Output
$null = Read-Host

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

"`nRemoving resource groups in order..." | Write-Output
Remove-ResourceGroupFromAzure -ResourceGroupName $rgApplication
Remove-ResourceGroupFromAzure -ResourceGroupName $rgSecondaryApplication
Remove-ResourceGroupFromAzure -ResourceGroupName $rgSpoke
Remove-ResourceGroupFromAzure -ResourceGroupName $rgSecondarySpoke
Remove-ResourceGroupFromAzure -ResourceGroupName $rgHub

# if ($CleanupAzureDirectory -eq $true -and (Test-Path -Path ./.azure -PathType Container)) {
#     "Cleaning up Azure Developer CLI state files." | Write-Output
#     Remove-Item -Path ./.azure -Recurse -Force
# }

"`nCleanup complete." | Write-Output