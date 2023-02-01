# This script is used by our QA process to ensure the quality of this sample it measures
# characteristics of the deployment and will be modified as needed to explore intermittent issues

# This engineering code may be repurposed for your scenario as desired
# but is not covered by the guidance in this content.

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
    created by the azd command. The cmdlet will populate the App Config Svc and Key
    Vault services in this resource group with Azure AD app registration config data.
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

$frontEndWebAppName=$(az resource list -g "$ResourceGroupName" --query "[? tags.\`"azd-service-name\`" == 'web' ].name" -o tsv)

if ($frontEndWebAppName.Length -eq 0) {
  Write-Error  "Cannot find the front-end web app"
  Write-Error "Recommended Action: run the 'azd provision' command again to overlay the missing settings"
  exit 32
} else {
  Write-Debug "Found front-end web app named '$frontEndWebAppName'"
}

$frontEndAppSvcUri=$(az webapp config appsettings list -n $frontEndWebAppName -g $ResourceGroupName --query "[?name=='App:AppConfig:Uri'].value" -o tsv)

if ($frontEndAppSvcUri.Length -eq 0) {
  Write-Error "Missing required Azure App Service configuration setting front-end web app: App:AppConfig:Uri"
  Write-Error "Recommended Action: run the 'azd provision' command again to overlay the missing settings"
  exit 33
} else {
  Write-Debug "Validated that the App Service was configured with setting 'App:AppConfig:Uri' equal to '$frontEndAppSvcUri'"
}

$apiWebAppName=$(az resource list -g "$ResourceGroupName" --query "[? tags.\`"azd-service-name\`" == 'api' ].name" -o tsv)

if ($apiWebAppName.Length -eq 0 ) {
  Write-Error "Cannot find the API web app"
  Write-Error "Recommended Action: run the 'azd provision' command again to overlay the missing settings"
  exit 34
} else {
  Write-Debug "Found API web app named '$apiWebAppName'"
}

$apiAppSvcUri=$(az webapp config appsettings list -n $apiWebAppName -g $ResourceGroupName --query "[?name=='Api:AppConfig:Uri'].value" -o tsv)

if ($apiAppSvcUri.Length -eq 0) {
  Write-Error "Missing required Azure App Service configuration setting for api web app: Api:AppConfig:Uri"
  Write-Error "Recommended Action: run the 'azd provision' command again to overlay the missing settings"
  exit 35
} else {
  Write-Debug "Validated that the App Service was configured with setting 'Api:AppConfig:Uri' equal to '$apiAppSvcUri'"
}

# end of check for issue 87

Write-Host "All settings validated successfully..."
Write-Host "If this script was unable to diagnose your problem then please create a GitHub issue"
exit 0