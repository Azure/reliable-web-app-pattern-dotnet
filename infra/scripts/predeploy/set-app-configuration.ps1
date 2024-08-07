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

Param(
    [Alias("g")]
    [Parameter(Mandatory = $true, HelpMessage = "Name of the application resource group that was created by azd")]
    [String]$ResourceGroupName,
    [Parameter(Mandatory = $true, HelpMessage = "URI used for OAuth with Microsoft Entra ID. This is the URI of the web app.")]
    [String]$WebUri,
    [Parameter(Mandatory = $false, HelpMessage = "Use default values for all prompts")]
    [Switch]$NoPrompt
)

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
        Write-Error "Failed to import the 'Az' module. Please install and import the 'Az' module before running this script."
        exit 12
    }
}

# Prompt formatting features

$defaultColor = if ($PSVersionTable.PSVersion.Major -ge 6) { "`e[0m" } else { "" }
$successColor = if ($PSVersionTable.PSVersion.Major -ge 6) { "`e[32m" } else { "" }
$highlightColor = if ($PSVersionTable.PSVersion.Major -ge 6) { "`e[36m" } else { "" }

# End of Prompt formatting features

function Get-WorkloadSqlManagedIdentityConnectionString {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    Write-Host "`tGetting sql server connection for $highlightColor'$ResourceGroupName'$defaultColor"

    $group = Get-AzResourceGroup -Name $ResourceGroupName

    # the group contains tags that explain what the default name of the Azure SQL resource should be
    $sqlServerResourceName = "sql-$($group.Tags["ResourceToken"])"
    $sqlDatabaseCatalogName = "relecloud-$($group.Tags["ResourceToken"])"

    # if sql server is not found, then throw an error
    if ($sqlServerResourceName.Length -lt 4) {
        throw "SQL server not found in resource group $group.ResourceGroupName"
    }

    $sqlServerResource = Get-AzSqlServer -ServerName $sqlServerResourceName -ResourceGroupName $group.ResourceGroupName

    return "Server=tcp:$($sqlServerResource.FullyQualifiedDomainName),1433;Initial Catalog=$($sqlDatabaseCatalogName);Authentication=Active Directory Default; Connect Timeout=180"
}

function Get-WorkloadRedisManagedIdentityConnectionString {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    Write-Host "`tGetting redis server connection for $highlightColor'$ResourceGroupName'$defaultColor"

    $group = Get-AzResourceGroup -Name $ResourceGroupName
    $redisName = "application-redis-db-$($group.Tags["ResourceToken"])"

    return "$redisName.redis.cache.windows.net:6380,ssl=True,abortConnect=False"
}

function Get-WorkloadStorageAccount {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    Write-Host "`tGetting storage account for $highlightColor'$ResourceGroupName'$defaultColor"

    $group = Get-AzResourceGroup -Name $ResourceGroupName

    # the group contains tags that explain what the default name of the storage account should be
    $storageAccountName = "st$($group.Tags["Environment"])$($group.Tags["ResourceToken"])"

    # if storage account is not found, then throw an error
    if ($storageAccountName.Length -lt 6) {
        throw "Storage account not found in resource group $group.ResourceGroupName"
    }

    return Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $group.ResourceGroupName
}

function Get-WorkloadKeyVault {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    Write-Host "`tGetting key vault for $highlightColor'$ResourceGroupName'$defaultColor"

    $group = Get-AzResourceGroup -Name $ResourceGroupName
    $hubGroup = Get-AzResourceGroup -Name $group.Tags["HubGroupName"]

    # the group contains tags that explain what the default name of the kv should be
    $keyVaultName = "kv-$($hubGroup.Tags["ResourceToken"])"

    # if key vault is not found, then throw an error
    if ($keyVaultName.Length -lt 4) {
        throw "Key vault not found in resource group $hubGroup.ResourceGroupName"
    }

    return Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $hubGroup.ResourceGroupName
}

Write-Host "Configuring app settings for $highlightColor'$ResourceGroupName'$defaultColor"

# default settings
$defaultAzureStorageTicketContainerName = "tickets" # matches the default defined in application-resources.bicep file
$defaultSqlConnectionString = (Get-WorkloadSqlManagedIdentityConnectionString -ResourceGroupName $ResourceGroupName) # the connection string to the SQL database set with Managed Identity
$defaultAzureStorageTicketUri = (Get-WorkloadStorageAccount -ResourceGroupName $ResourceGroupName).PrimaryEndpoints.Blob # the URI of the storage account container where tickets are stored
$defaultRedisConnectionString = (Get-WorkloadRedisManagedIdentityConnectionString -ResourceGroupname $ResourceGroupname) # the connection string to the redis database set with managed identity
$defaultAzureFrontDoorHostName = $WebUri.Substring("https://".Length) # the hostname of the front door
$defaultRelecloudBaseUri = "$WebUri/api" # used by the frontend to call the backend through the front door
$defaultKeyVaultUri = (Get-WorkloadKeyVault -ResourceGroupName $ResourceGroupName).VaultUri # the URI of the key vault where secrets are stored

# prompt to confirm settings
$azureStorageTicketContainerName = ""
if (-not $NoPrompt) {
    $azureStorageTicketContainerName = Read-Host -Prompt "`nWhat value should be used for the Azure storage container name? [default: $highlightColor$defaultAzureStorageTicketContainerName$defaultColor]"
}

if ($azureStorageTicketContainerName -eq "") {
    $azureStorageTicketContainerName = $defaultAzureStorageTicketContainerName
}

$sqlConnectionString = ""
if (-not $NoPrompt) {
    $sqlConnectionString = Read-Host -Prompt "`nWhat value should be used for the SQL connection string? [default: $highlightColor$defaultSqlConnectionString$defaultColor]"
}

if ($sqlConnectionString -eq "") {
    $sqlConnectionString = $defaultSqlConnectionString
}

$redisConnectionString = ""
if (-not $NoPrompt) {
    $redisConnectionString = Read-Host -Prompt "`nWhat value should be used for the Redis connection string? [default: $highlightColor$defaultRedisConnectionString$defaultColor]"
}

if ($redisConnectionString -eq "") {
    $redisConnectionString = $defaultRedisConnectionString
}

$azureStorageTicketUri = ""
if (-not $NoPrompt) {
    $azureStorageTicketUri = Read-Host -Prompt "`nWhat value should be used for the Azure storage URI? [default: $highlightColor$defaultAzureStorageTicketUri$defaultColor]"
}

if ($azureStorageTicketUri -eq "") {
    $azureStorageTicketUri = $defaultAzureStorageTicketUri
}

$azureFrontDoorHostName = ""
if (-not $NoPrompt) {
    $azureFrontDoorHostName = Read-Host -Prompt "`nWhat value should be used for the Azure Front Door Host? [default: $highlightColor$defaultAzureFrontDoorHostName$defaultColor]"
}

if ($azureFrontDoorHostName -eq "") {
    $azureFrontDoorHostName = $defaultAzureFrontDoorHostName
}

$relecloudBaseUri = ""
if (-not $NoPrompt) {
    $relecloudBaseUri = Read-Host -Prompt "`nWhat value should be used for the Relecloud Base URI? [default: $highlightColor$defaultRelecloudBaseUri$defaultColor]"
}

if ($relecloudBaseUri -eq "") {
    $relecloudBaseUri = $defaultRelecloudBaseUri
}

$keyVaultUri = ""
if (-not $NoPrompt) {
    $keyVaultUri = Read-Host -Prompt "`nWhat value should be used for the Key Vault URI? [default: $highlightColor$defaultKeyVaultUri$defaultColor]"
}

if ($keyVaultUri -eq "") {
    $keyVaultUri = $defaultKeyVaultUri
}

# display the settings so that the user can verify them in the output log
Write-Host "`nWorking settings:"
Write-Host "`tazureStorageTicketContainerName: $highlightColor'$azureStorageTicketContainerName'$defaultColor"
Write-Host "`tresourceGroupName: $highlightColor'$resourceGroupName'$defaultColor"
Write-Host "`tSqlConnectionString: $highlightColor'$sqlConnectionString'$defaultColor"
Write-Host "`tRedistConnectionString: $highlightColor'$redisConnectionString'$defaultColor"
Write-Host "`tAzureStorageTicketUri: $highlightColor'$azureStorageTicketUri'$defaultColor"
Write-Host "`tAzureFrontDoorHostName: $highlightColor'$azureFrontDoorHostName'$defaultColor"
Write-Host "`tRelecloudBaseUri: $highlightColor'$relecloudBaseUri'$defaultColor"

# handles multi-regional app configuration because the app config must be in the same region as the code deployment
$configStore = Get-AzAppConfigurationStore -ResourceGroupName $resourceGroupName

try {
    Write-Host "`nSetting values in $highlightColor$($configStore.Endpoint)$defaultColor..."

    Write-Host "`nSet values for backend..."
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:SqlDatabase:ConnectionString -Value $sqlConnectionString > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Container -Value $azureStorageTicketContainerName > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:StorageAccount:Uri -Value $azureStorageTicketUri > $null

    Write-Host "Set values for frontend..."
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:FrontDoorHostname -Value $azureFrontDoorHostName > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RelecloudApi:BaseUri -Value $relecloudBaseUri > $null

    Write-Host "Set values for redis..."
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:Redis:ConnectionString -Value $redisConnectionString > $null

    Write-Host "Set values for key vault references..."
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:MicrosoftEntraId:ClientId -Value "{ `"uri`":`"$($keyVaultUri)secrets/Api--MicrosoftEntraId--ClientId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:MicrosoftEntraId:Instance -Value "{ `"uri`":`"$($keyVaultUri)secrets/Api--MicrosoftEntraId--Instance`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key Api:MicrosoftEntraId:TenantId -Value "{ `"uri`":`"$($keyVaultUri)secrets/Api--MicrosoftEntraId--TenantId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key App:RelecloudApi:AttendeeScope -Value "{ `"uri`":`"$($keyVaultUri)secrets/App--RelecloudApi--AttendeeScope`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:Instance -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--Instance`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:CallbackPath -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--CallbackPath`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:ClientId -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--ClientId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:ClientSecret -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--ClientSecret`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:Instance -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--Instance`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:SignedOutCallbackPath -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--SignedOutCallbackPath`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null
    Set-AzAppConfigurationKeyValue -Endpoint $configStore.Endpoint -Key MicrosoftEntraId:TenantId -Value "{ `"uri`":`"$($keyVaultUri)secrets/MicrosoftEntraId--TenantId`"}" -ContentType 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8' > $null

    Write-Host "`nFinished set-app-configuration $($successColor)successfully$($defaultColor).`n"
}
catch {
    "Failed to set app configuration values" | Write-Error
    throw $_
}
