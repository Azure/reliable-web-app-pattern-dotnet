# This script is run by azd pre-down hook and is part of the deployment lifecycle run when deploying the code for the Relecloud web app.

# Function definitions

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

# Removed all budgets that are scoped to a resource group of interest.
function Remove-ConsumptionBudgetForResourceGroup($resourceGroupName) {
    # Get-AzConsumptionBudget -ResourceGroupName $resourceGroupName
    Get-AzBudget -ResourceGroupName $resourceGroupName
    | Foreach-Object {
        "`tRemoving $resourceGroupName::$($_.name)" | Write-Output
        Remove-AzConsumptionBudget -Name $_.name -ResourceGroupName $resourceGroupName
    }
}

function Test-ResourceGroupExists($resourceGroupName) {
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    return $null -ne $resourceGroup
}

# end of functions

$hubGroupName = ((azd env get-values --output json) | ConvertFrom-Json).hub_group_name

if (-not $hubGroupName) {
    Write-Host "Azure hub group name not found in environment variables. No cleanup needed. Exiting..."
}
else {
    Write-Host "Removing budgets for resource group $hubGroupName"
    Remove-ConsumptionBudgetForResourceGroup -ResourceGroupName $hubGroupName
}

$resourceGroupName = ((azd env get-values --output json) | ConvertFrom-Json).AZURE_RESOURCE_GROUP

if (-not $resourceGroupName) {
    Write-Host "Azure hub group name not found in environment variables. No cleanup needed. Exiting..."
}
else {
    Write-Host "Removing budgets for resource group $resourceGroupName"
    Remove-ConsumptionBudgetForResourceGroup -ResourceGroupName $resourceGroupName
}

# todo - remove diagnostic settings
# todo - remove app registration