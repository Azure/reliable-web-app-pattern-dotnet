<#
.SYNOPSIS
    Creates two Azure AD app registrations for the scalable-web-app-pattern-dotnet
    and saves the configuration data in App Configuration Svc and Key Vault.

    <This command should only be run after using the azd command to deploy resources to Azure>
.DESCRIPTION
    The Relecloud web app uses Azure AD to authenticate and authorize the users that can
    make concert ticket purchases. To prove that the website is a trusted, and secure, resource
    the web app must handshake with Azure AD by providing the configuration settings like the following.
    - TenantID identifies which Azure AD instance holds the users that should be authorized
    - ClientID identifies which app this code says it represents
    - ClientSecret provides a secret known only to Azure AD, and shared with the web app, to
    validate that Azure AD can trust this web app

    This script will create the App Registrations that provide these configurations. Once those
    are created the configuration data will be saved to Azure App Configuration and the secret
    will be saved in Azure Key Vault so that the web app can read these values and provide them
    to Azure AD during the authentication process.

    NOTE: This functionality assumes that the web app, app configuration service, and app
    service have already been successfully deployed.

.PARAMETER ResourceGroupName
    A required parameter for the name of resource group that contains the environment that was
    created by the azd command. The cmdlet will populate the App Config Svc and Key
    Vault services in this resource group with Azure AD app registration config data.
.PARAMETER SecondaryResourceGroupName
    An optional parameter that describes the name of the second resource group that contains the
    resources deployed by the azd command. The cmdlet will populate the App Config Svc and Key
    Vault services in this resource group with Azure AD app registration config data.
#>

Param(
    [Alias("g")]
    [Parameter(Mandatory = $true, HelpMessage = "Name of the resource group that was created by azd")]
    [String]$ResourceGroupName,
    
    [Alias("sg")]
    [String]$SecondaryResourceGroupName
)

$canSetSecondAzureLocation = 1

Write-Debug "Inputs"
Write-Debug "----------------------------------------------"
Write-Debug "resourceGroupName='$resourceGroupName'"
Write-Debug ""

$groupExists = (az group exists -n $ResourceGroupName)
if ($groupExists -eq 'false') {
    Write-Error "FATAL ERROR: $ResourceGroupName could not be found in the current subscription"
    exit 6
}
else {
    Write-Debug "Found resource group named: $ResourceGroupName"
}

$keyVaultName = (az keyvault list -g "$ResourceGroupName" --query "[? starts_with(name,'rc-')].name" -o tsv)
$appConfigSvcName = (az appconfig list -g "$ResourceGroupName" --query "[].name" -o tsv)


$appServiceRootUri = 'azurewebsites.net' # hard coded because app svc does not return the public endpoint
$frontEndWebAppName = (az resource list -g "$ResourceGroupName" --query "[? tags.\`"azd-service-name\`" == 'web' ].name" -o tsv)
$frontEndWebAppUri = "https://$frontEndWebAppName.$appServiceRootUri"

$resourceToken = $frontEndWebAppName.substring(4, 13)
$environmentName = $ResourceGroupName.substring(0, $ResourceGroupName.Length - 3)

Write-Debug "Derived inputs"
Write-Debug "----------------------------------------------"
Write-Debug "keyVaultName=$keyVaultName"
Write-Debug "appConfigSvcName=$appConfigSvcName"
Write-Debug "frontEndWebAppUri=$frontEndWebAppUri"
Write-Debug "resourceToken=$resourceToken"
Write-Debug "environmentName=$environmentName"
Write-Debug ""

if ($keyVaultName.Length -eq 0) {
    Write-Error "FATAL ERROR: Could not find Key Vault resource. Confirm the --ResourceGroupName is the one created by the ``azd provision`` command."
    exit 7
}

Write-Debug "Runtime values"
Write-Debug "----------------------------------------------"
$frontEndWebAppName = "$environmentName-$resourceToken-frontend"
$apiWebAppName = "$environmentName-$resourceToken-api"
$maxNumberOfRetries = 20

Write-Debug "frontEndWebAppName='$frontEndWebAppName'"
Write-Debug "apiWebAppName='$apiWebAppName'"
Write-Debug "maxNumberOfRetries=$maxNumberOfRetries"

$tenantId = (az account show --query "tenantId" -o tsv)
$userObjectId = (az account show --query "id" -o tsv)

Write-Debug "tenantId='$tenantId'"
Write-Debug ""

$frontEndWebObjectId = (az ad app list --filter "displayName eq '$frontEndWebAppName'" --query "[].id" -o tsv)


if ($frontEndWebObjectId.Length -eq 0) {

    # quietly: grant the current user secrets management access to Key Vault so we can set keys
    az keyvault set-policy -n $keyVaultName --secret-permissions all --object-id $userObjectId > $null

    # this web app doesn't exist and must be creaed
    
    $frontEndWebAppClientId = (az ad app create `
            --display-name $frontEndWebAppName `
            --sign-in-audience AzureADMyOrg `
            --app-roles '"[{ \"allowedMemberTypes\": [ \"User\" ], \"description\": \"Relecloud Administrator\", \"displayName\": \"Relecloud Administrator\", \"isEnabled\": \"true\", \"value\": \"Administrator\" }]"' `
            --web-redirect-uris $frontEndWebAppUri/signin-oidc https://localhost:7227/signin-oidc `
            --enable-id-token-issuance `
            --query appId --output tsv)

    Write-Host "frontEndWebAppClientId='$frontEndWebAppClientId'"

    if ($frontEndWebAppClientId.Length -eq 0) {
        Write-Error  "FATAL ERROR: Failed to create front-end app registration"
        exit 8
    }

    $isWebAppCreated = 0
    $currentRetryCount = 0
    while ( $isWebAppCreated -eq 0) {
        # assumes that we only need to create client secret if the app registration did not exist
        $frontEndWebAppClientSecret = (az ad app credential reset --id $frontEndWebAppClientId --query "password" -o tsv --only-show-errors 2> $null) 
        $isWebAppCreated = $frontEndWebAppClientSecret.Length # treating 0 as $false and positive nums as $true
  
        $currentRetryCount++

        if ($currentRetryCount -gt $maxNumberOfRetries) {
            Write-Error "FATAL ERROR: Tried to create a client secret too many times"
            exit 14
        }

        if ($isWebAppCreated -eq 0) {
            Write-Debug "... trying to create clientSecret for front-end attempt #$currentRetryCount"
        }
        else {
            Write-Host "... created clientSecret for front-end"
            Write-Host ""
        }

        # sleep until the app registration is created
        Start-Sleep -Seconds 3
    }

    # save 'AzureAd:ClientSecret' to Key Vault
    az keyvault secret set --name 'AzureAd--ClientSecret' --vault-name $keyVaultName --value $frontEndWebAppClientSecret --only-show-errors > $null
    Write-Host "Set keyvault value for: 'AzureAd--ClientSecret'"

    # save 'AzureAd:TenantId' to App Config Svc
    az appconfig kv set --name $appConfigSvcName --key 'AzureAd:TenantId' --value $tenantId --yes --only-show-errors > $null
    Write-Host "Set appconfig value for: 'AzureAd:TenantId'"

    #save 'AzureAd:ClientId' to App Config Svc
    az appconfig kv set --name $appConfigSvcName --key 'AzureAd:ClientId' --value $frontEndWebAppClientId --yes --only-show-errors > $null
    Write-Host "Set appconfig value for: 'AzureAd:ClientId'"

}
else {
    Write-Host "frontend app registration objectId=$frontEndWebObjectId already exists. Delete the '$frontEndWebAppName' app registration to recreate or reset the settings."
    $frontEndWebAppClientId = (az ad app show --id $frontEndWebObjectId --query "appId" -o tsv)
    $canSetSecondAzureLocation = 2
}

Write-Host ""
Write-Host "Finished app registration for front-end"
Write-Host ""

$apiObjectId = (az ad app list --filter "displayName eq '$apiWebAppName'" --query "[].id" -o tsv)


if ( $apiObjectId.Length -eq 0 ) {
    # the api app registration does not exist and must be created
    
    $apiWebAppClientId = (az ad app create `
            --display-name $apiWebAppName `
            --sign-in-audience AzureADMyOrg `
            --app-roles '[{ \"allowedMemberTypes\": [ \"User\" ], \"description\": \"Relecloud Administrator\", \"displayName\": \"Relecloud Administrator\", \"isEnabled\": \"true\", \"value\": \"Administrator\" }]' `
            --query appId --output tsv)

    Write-Debug "apiWebAppClientId='$apiWebAppClientId'"

    # sleep until the app registration is created correctly
    $isApiCreated = 0
    $currentRetryCount = 0
    
    while ($isApiCreated -eq 0) {
        $apiObjectId = (az ad app show --id $apiWebAppClientId --query id -o tsv 2> $null)
        $isApiCreated = $apiObjectId.Length # treating 0 as $false and positive nums as $true

        $currentRetryCount++
        if ($currentRetryCount -gt $maxNumberOfRetries) {
            Write-Error 'FATAL ERROR: Tried to create retrieve the apiObjectId too many times'
            exit 15
        }

        if ($isApiCreated -eq 0) {
            Write-Debug "... trying to retrieve apiObjectId attempt #$currentRetryCount"
        }
        else {
            Write-Debug "... retrieved apiObjectId='$apiObjectId'"
        }
        
        Start-Sleep -Seconds 3
    }

    # Expose an API by defining a scope
    # application ID URI will be clientId by default

    $scopeName = 'relecloud.api'

    $isScopeAdded = 0
    $currentRetryCount = 0

    while ($isScopeAdded -eq 0) {
    
        az rest `
            --method PATCH `
            --uri "https://graph.microsoft.com/v1.0/applications/$apiObjectId" `
            --headers 'Content-Type=application/json' `
            --body "{ identifierUris:[ 'api://$apiWebAppClientId' ], api: { oauth2PermissionScopes: [ { value: '$scopeName', adminConsentDescription: 'Relecloud API access', adminConsentDisplayName: 'Relecloud API access', id: 'c791b666-cc87-4904-bc9f-c5945e08ba8f', isEnabled: true, type: 'Admin' } ] } }" 2> $null

        $createdScope = (az ad app show --id $apiWebAppClientId --query 'api.oauth2PermissionScopes[0].value' -o tsv 2> $null)

        if ($createdScope -eq $scopeName) {
            $isScopeAdded = 1
            Write-Debug "... added scope $scopeName"
        }
        else {
            $currentRetryCount++
            Write-Host "... trying to add scope attempt #$currentRetryCount"
            if ($currentRetryCount -gt $maxNumberOfRetries) {
                Write-Error 'FATAL ERROR: Tried to set scopes too many times'
                exit 16
            }
        }

        Start-Sleep -Seconds 3
    }

    Write-Host "... assigned scope to api"
    
    $permId = ''
    $currentRetryCount = 0
    while ($permId.Length -eq 0 ) {
        $permId = (az ad app show --id $apiWebAppClientId --query 'api.oauth2PermissionScopes[].id' -o tsv 2> $null)

        if ($permId.Length -eq 0 ) {
            $currentRetryCount++
            Write-Debug "... trying to retrieve permId attempt #$currentRetryCount"

            if ($currentRetryCount -gt $maxNumberOfRetries) {
                Write-Error 'FATAL ERROR: Tried to retrieve permissionId too many times'
                exit 17
            }
        }
        else {
            Write-Debug "... retrieved permId=$permId"
        }
  
        Start-Sleep -Seconds 3
    }

    $preAuthedAppApplicationId = $frontEndWebAppClientId

    # Preauthorize the front-end as a client to suppress scope requests
    $authorizedApps = ''
    $currentRetryCount = 0
    while ($authorizedApps.Length -eq 0) {
        az rest  `
            --method PATCH `
            --uri "https://graph.microsoft.com/v1.0/applications/$apiObjectId" `
            --headers 'Content-Type=application/json' `
            --body "{api:{preAuthorizedApplications:[{appId:'$preAuthedAppApplicationId',delegatedPermissionIds:['$permId']}]}}" 2> $null

        $authorizedApps = (az ad app show --id $apiObjectId --query "api.preAuthorizedApplications" -o tsv 2> $null)

        if ($authorizedApps.Length -eq 0) {
            $currentRetryCount++
            Write-Debug "... trying to set front-end app as an preAuthorized client attempt #$currentRetryCount"

            if ($currentRetryCount -gt $maxNumberOfRetries) {
                Write-Error 'FATAL ERROR: Tried to authorize the front-end app too many times'
                exit 18
            }
        }
        else {
            Write-Host "front-end web app is now preAuthorized"
            Write-Host ""
        }   

        Start-Sleep -Seconds 3
    }
    
    # save 'App:RelecloudApi:AttendeeScope' scope for role to App Config Svc
    az appconfig kv set --name $appConfigSvcName --key 'App:RelecloudApi:AttendeeScope' --value "api://$apiWebAppClientId/$scopeName" --yes --only-show-errors > $null
    Write-Host "Set appconfig value for: 'App:RelecloudApi:AttendeeScope'"

    # save 'Api:AzureAd:ClientId' to App Config Svc
    az appconfig kv set --name $appConfigSvcName --key 'Api:AzureAd:ClientId' --value $apiWebAppClientId --yes --only-show-errors > $null
    Write-Host "Set appconfig value for: 'Api:AzureAd:ClientId'"

    # save 'Api:AzureAd:TenantId' to App Config Svc
    az appconfig kv set --name $appConfigSvcName --key 'Api:AzureAd:TenantId' --value $tenantId --yes --only-show-errors > $null
    Write-Host "Set appconfig value for: 'Api:AzureAd:TenantId'"

} 
else {
    Write-Host "API app registration objectId=$apiObjectId already exists. Delete the '$apiWebAppName' app registration to recreate or reset the settings."
    $canSetSecondAzureLocation = 3
}

############## Copy the App Configuration and Key Vault settings to second azure location ##############

if (${#secondaryResourceGroupName} -gt 0 && $canSetSecondAzureLocation -eq 1) {
    
  # assumes there is only one vault deployed to this resource group that will match this filter
  $secondaryKeyVaultName = (az keyvault list -g "$secondaryResourceGroupName" --query "[? name.starts_with(@,'rc-') ].name" -o tsv)

  $secondaryAppConfigSvcName = (az appconfig list -g "$secondaryResourceGroupName" --query "[].name" -o tsv)

  Write-Debug ""
  Write-Debug "Derived inputs for second azure location"
  Write-Debug "----------------------------------------------"
  Write-Debug "secondaryKeyVaultName=$secondaryKeyVaultName"
  Write-Debug "secondaryAppConfigSvcName=$secondaryAppConfigSvcName"

  Write-Debug ""
  Write-Debug "Now configuring secondary key vault"

  # save 'AzureAd:ClientSecret' to Key Vault
  az keyvault secret set --name 'AzureAd--ClientSecret' --vault-name $secondaryKeyVaultName --value $frontEndWebAppClientSecret --only-show-errors > $null
  Write-Host "... Set keyvault value for: 'AzureAd--ClientSecret'"

  Write-Host ""
  Write-Host "Now configuring secondary app config svc"
  # save 'AzureAd:TenantId' to App Config Svc
  az appconfig kv set --name $secondaryAppConfigSvcName --key 'AzureAd:TenantId' --value $tenantId --yes --only-show-errors > $null
  Write-Host "... Set appconfig value for: 'AzureAd:TenantId'"

  #save 'AzureAd:ClientId' to App Config Svc
  az appconfig kv set --name $secondaryAppConfigSvcName --key 'AzureAd:ClientId' --value $frontEndWebAppClientId --yes --only-show-errors > $null
  Write-Host "... Set appconfig value for: 'AzureAd:ClientId'"
  
  # save 'App:RelecloudApi:AttendeeScope' scope for role to App Config Svc
  az appconfig kv set --name $secondaryAppConfigSvcName --key 'App:RelecloudApi:AttendeeScope' --value "api://$apiWebAppClientId/$scopeName" --yes --only-show-errors > $null
  Write-Host "... Set appconfig value for: 'App:RelecloudApi:AttendeeScope'"

  # save 'Api:AzureAd:ClientId' to App Config Svc
  az appconfig kv set --name $secondaryAppConfigSvcName --key 'Api:AzureAd:ClientId' --value $apiWebAppClientId --yes --only-show-errors > $null
  Write-Host "... Set appconfig value for: 'Api:AzureAd:ClientId'"
    
  # save 'Api:AzureAd:TenantId' to App Config Svc
  az appconfig kv set --name $secondaryAppConfigSvcName --key 'Api:AzureAd:TenantId' --value $tenantId --yes --only-show-errors > $null
  Write-Host "... Set appconfig value for: 'Api:AzureAd:TenantId'"
    
} elseif ($canSetSecondAzureLocation -eq 2) {
    Write-Host ""
    Write-Host "skipped setup for secondary azure location because frontend app registration objectId=$frontEndWebObjectId already exists."
} elseif ($canSetSecondAzureLocation -eq 3) {
    Write-Host ""
    Write-Host "skipped setup for secondary location because API app registration objectId=$apiObjectId already exists."
}

# all done
exit 0