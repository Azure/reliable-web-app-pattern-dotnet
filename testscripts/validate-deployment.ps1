#Requires -Version 7.0

<#
.SYNOPSIS
    Examines the web app that was deployed to identify any known issues and provide recommendations.

    <This command should only be run after using the azd command to deploy resources to Azure>
.DESCRIPTION
    Use this command to examine your deployed settings and automatically find recommendations
    that can help you troubleshoot issues that you may encounter.

    This script was created after identifying intermittent Azure deployment issues. Many
    of which can be resolved by re-running 'azd provision' command.

    NOTE: This functionality assumes that the web app, app configuration service, and app
    service have already been successfully deployed.

.PARAMETER ResourceGroupName
    A required parameter for the name of resource group that contains the environment that was
    created by the azd command.
#>

Param(
    [Alias("g")]
    [Parameter(Mandatory = $true, HelpMessage = "Name of the resource group that was created by azd")]
    [String]$ResourceGroupName
)

if ($ResourceGroupName.Length -eq 0) {
  Write-Error 'FATAL ERROR: Missing required parameter --resource-group'
  exit 6
}

if ($ResourceGroupName -eq '-rg') {
  Write-Error 'FATAL ERROR: Required parameter --resource-group was not initialized'
  exit 7
}

### check if group exists ###

$groupExists=$(az group exists -n $ResourceGroupName)

if ($groupExists -eq 'false') {
  Write-Error "Missing required resource group. The resource group '$ResourceGroupName' does not exist"
  Write-Error "Recommended Action: run the `azd provision` command again to overlay the missing settings"
  exit 32
} else {
  Write-Debug "Validated that the resource group does exist"
}

### end check group exists ###


### validate web app settings ###

# checking for known issue 87
# https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/87

foreach ($appTag in @("web-callcenter-frontend", "web-callcenter-service")) {

  $appName=$(az resource list -g "$ResourceGroupName" --query "[? tags.\`"azd-service-name\`" == '$appTag' ].name" -o tsv)

  if ($appName.Length -eq 0) {
    Write-Error "Cannot find the app with tag: $appTag"
    Write-Error "Recommended Action: run the 'azd provision' command again to overlay the missing settings"
    exit 32
  } else {
    Write-Debug "Found app with tag: $appTag, appName: $appName"
  }

  # Determine which appConfig key we are looking for depending on api versus web flavor of our application
  if ($appTag -like "*api") {
    $appSettingConfig="Api:AppConfig:Uri"
  } else {
    $appSettingConfig="App:AppConfig:Uri" 
  }

  $AppSvcUri=$(az webapp config appsettings list -n $appName -g $ResourceGroupName --query "[?name=='$appSettingConfig'].value" -o tsv)

  if ($AppSvcUri.Length -eq 0) {
    Write-Error "Missing required Azure App Service configuration setting $appSettingConfig in app: $appName"
    Write-Error "Recommended Action: run the 'azd provision' command again to overlay the missing settings"
    exit 35
  } else {
    Write-Debug "Validated that the App Service was configured with setting $appSettingsConfig equal to '$AppSvcUri'"
  }
}


# end of check for issue 87

Write-Host "All settings validated successfully..."
Write-Host "If this script was unable to diagnose your problem then please create a GitHub issue"
exit 0