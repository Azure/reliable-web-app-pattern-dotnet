#Requires -Version 7.0

<#
.SYNOPSIS
    Will show a json snippet you can save in Visual Studio secrets.json file to run the code locally.
.DESCRIPTION
    Supports the local development workflow by retrieving the secrets and configuration necessary
    to run the web app sample locally. The secrets and configurations displayed as outputs from this
    command should be copied into a secrets.json file to keep secrets out of source control.

    <This command should only be run after using the azd command to deploy resources to Azure>
.PARAMETER ResourceGroupName
    Name of resource group containing the environment that was created by the azd command.
.PARAMETER Web
    Print the json snippet for the api web app. Defaults to False.
.PARAMETER Api
    Print the json snippet for the front-end web app. Defaults to False.
#>

Param(
  [Alias("g")]
  [Parameter(Mandatory = $true, HelpMessage = "Name of the resource group that was created by azd")]
  [String]$ResourceGroupName,
    
  [Alias("w")]
  [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false)]
  [switch]$Web,
    
  [Alias("a")]
  [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false)]
  [switch]$Api
)

$web_app = $Web
$api_app = $Api

$groupExists = (az group exists -n $ResourceGroupName)
if ($groupExists -eq 'false') {
  Write-Error "FATAL ERROR: $ResourceGroupName could not be found in the current subscription"
  exit 6
}
else {
  Write-Debug "Found resource group named: $ResourceGroupName"
}

Write-Debug "`$web_app=$web_app"
Write-Debug "`$api_app=$api_app"

if ( $web_app -eq $false -and $api_app -eq $false ) {
  Write-Error 'FATAL ERROR: Missing required flag -Web or -Api'
  exit 7
}

Write-Debug ""
Write-Debug "Inputs"
Write-Debug "----------------------------------------------"
Write-Debug "ResourceGroupName='$ResourceGroupName'"
Write-Debug ""

# assumes there is only one vault deployed to this resource group that will match this filter
$keyVaultName = (az keyvault list -g "$ResourceGroupName" --query "[? name.starts_with(@,'rc-') ].name" -o tsv)

$appConfigSvcName = (az resource list -g $ResourceGroupName --query "[? type== 'Microsoft.AppConfiguration/configurationStores' ].name" -o tsv)

$appConfigUri = (az appconfig show -n $appConfigSvcName -g $ResourceGroupName --query "endpoint" -o tsv 2> $null)

Write-Debug "Derived inputs"
Write-Debug "----------------------------------------------"
Write-Debug "keyVaultName=$keyVaultName"
Write-Debug "appConfigSvcName=$appConfigSvcName"

###
# Step1: Print json snippet for web app
###

if ($web_app) {
  # get 'AzureAd:ClientSecret' from Key Vault
  $frontEndAzureAdClientSecret = (az keyvault secret show --vault-name $keyVaultName --name AzureAd--ClientSecret -o tsv --query "value" 2> $null) 
      
  # get 'App:RedisCache:ConnectionString' from Key Vault
  $frontEndRedisConnStr = (az keyvault secret show --vault-name $keyVaultName --name App--RedisCache--ConnectionString -o tsv --query "value" 2> $null) 

  # get 'App:RelecloudApi:AttendeeScope' from App Configuration Svc
  $frontEndAttendeeScope = (az appconfig kv show -n $appConfigSvcName --key App:RelecloudApi:AttendeeScope -o tsv --query value 2> $null) 

  # get 'App:RelecloudApi:BaseUri' from App Configuration svc
  # frontEndBaseUri=$(az appconfig kv show -n $appConfigSvcName --key App:RelecloudApi:BaseUri -o tsv --query value 2> $null) 
  $frontEndBaseUri = "https://localhost:7242"

  # get 'AzureAd:ClientId' from App Configuration svc
  $frontEndAzureAdClientId = (az appconfig kv show -n $appConfigSvcName --key AzureAd:ClientId -o tsv --query value 2> $null) 

  # get 'AzureAd:TenantId' from App Configuration svc
  $frontEndAzureAdTenantId = (az appconfig kv show -n $appConfigSvcName --key AzureAd:TenantId -o tsv --query value 2> $null) 

  Write-Host ""
  Write-Host "{"
  Write-Host "   `"App:AppConfig:Uri`": `"$appConfigUri`","
  Write-Host "   `"App:RedisCache:ConnectionString`": `"$frontEndRedisConnStr`","
  Write-Host "   `"App:RelecloudApi:AttendeeScope`": `"$frontEndAttendeeScope`","
  Write-Host "   `"App:RelecloudApi:BaseUri`": `"$frontEndBaseUri`","
  Write-Host "   `"AzureAd:ClientId`": `"$frontEndAzureAdClientId`","
  Write-Host "   `"AzureAd:ClientSecret`": `"$frontEndAzureAdClientSecret`","
  Write-Host "   `"AzureAd:TenantId`": `"$frontEndAzureAdTenantId`""
  Write-Host "}"
  Write-Host ""
  Write-Host "Successful" -ForegroundColor Green -NoNewline; Write-Host " use these values to start debugging locally"
}

if ($api_app) {
  # App:StorageAccount:ConnectionString
  $apiAppQueueConnStr = (az keyvault secret show --vault-name $keyVaultName --name App--StorageAccount--ConnectionString -o tsv --query "value" 2> $null) 

  # get 'App:RedisCache:ConnectionString' from Key Vault
  $apiAppRedisConnStr = (az keyvault secret show --vault-name $keyVaultName --name App--RedisCache--ConnectionString -o tsv --query "value" 2> $null) 

  # get 'Api:AzureAd:ClientId' from App Configuration svc
  $apiAppAzureAdClientId = (az appconfig kv show -n $appConfigSvcName --key Api:AzureAd:ClientId -o tsv --query value 2> $null) 

  # get 'Api:AzureAd:TenantId' from App Configuration svc
  $apiAppAzureAdTenantId = (az appconfig kv show -n $appConfigSvcName --key Api:AzureAd:TenantId -o tsv --query value 2> $null) 

  # App:SqlDatabase:ConnectionString
  $apiAppSqlConnStr = (az appconfig kv show -n $appConfigSvcName --key App:SqlDatabase:ConnectionString -o tsv --query value 2> $null) 

  Write-Host ""
  Write-Host "{"
  Write-Host "   `"Api:AppConfig:Uri`": `"$appConfigUri`","
  Write-Host "   `"Api:AzureAd:ClientId`": `"$apiAppAzureAdClientId`","
  Write-Host "   `"Api:AzureAd:TenantId`": `"$apiAppAzureAdTenantId`","
  Write-Host "   `"App:RedisCache:ConnectionString`": `"$apiAppRedisConnStr`","
  Write-Host "   `"App:SqlDatabase:ConnectionString`": `"$apiAppSqlConnStr`","
  Write-Host "   `"App:StorageAccount:QueueConnectionString`": `"$apiAppQueueConnStr`""
  Write-Host "}"
  Write-Host ""

  Write-Host "Successful" -ForegroundColor Green -NoNewline; Write-Host " use these values to start debugging locally"
}
