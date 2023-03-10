#!/bin/bash

# This script is part of the sample's workflow for configuring App Registrations
# in Azure AD and saving the appropriate values in Key Vault, and Azure App Config Service
# so that the application can authenticate users. Note that an app registration is
# something you'll want to set up once, and reuse for every version of the web app
# that you deploy. You can learn more about app registrations at
# https://learn.microsoft.com/en-us/azure/active-directory/develop/application-model
#
# If you do not have permission to create App Registrations consider
# sharing this script, or something similar, with your administrators to help them
# set up the variables you need to integrate with Azure AD
#
# This code may be repurposed for your scenario as desired
# but is not covered by the guidance in this content.

POSITIONAL_ARGS=()

debug=''

while [[ $# -gt 0 ]]; do
  case $1 in
    --resource-group|-g)
      resourceGroupName="$2"
      shift # past argument
      shift # past value
      ;;
    --debug)
      debug=1
      shift # past argument
      ;;
    --help*)
      echo ""
      echo "<This command should only be run after using the azd command to deploy resources to Azure>"
      echo ""
      echo "Command"
      echo "    createAppRegistrations.sh : Will create two app registrations for the reliable-web-app-pattern-dotnet and register settings with App Configuration Svc and Key Vault."
      echo ""
      echo "Arguments"
      echo "    --resource-group -g : Name of resource group containing the environment that was created by the azd command."
      echo ""
      exit 1
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

if [[ ${#resourceGroupName} -eq 0 ]]; then
  echo "FATAL ERROR: Missing required parameter --resource-group" 1>&2
  exit 6
fi

canSetSecondAzureLocation=1

echo "Inputs"
echo "----------------------------------------------"
echo "resourceGroupName='$resourceGroupName'"
echo ""

# assumes there is only one vault deployed to this resource group that will match this filter
keyVaultName=$(az keyvault list -g "$resourceGroupName" --query "[?name.starts_with(@,'rc-')].name" -o tsv)

appConfigSvcName=$(az appconfig list -g "$resourceGroupName" --query "[].name" -o tsv)

appServiceRootUri='azurewebsites.net' # hard coded because app svc does not return the public endpoint
# updated az resource selection to filter to first based on https://github.com/Azure/azure-cli/issues/25214
frontEndWebAppName=$(az resource list -g "$resourceGroupName" --query "[?tags.\"azd-service-name\"=='web'].name" -o tsv)
frontEndWebAppUri="https://$frontEndWebAppName.$appServiceRootUri"

# assumes resourceToken is located in app service frontend web app name
# assumes the uniquestring function from the bicep template always returns a string of length 13
resourceToken=${frontEndWebAppName:4:13}

# assumes environment name is used to build resourceGroupName
locationOfHyphen=$(echo $resourceGroupName | awk -F "-" '{print length($0)-length($NF)}')
environmentName=${resourceGroupName:0:$locationOfHyphen-1}


frontDoorProfileName=$(az resource list -g $resourceGroupName --query "[? kind=='frontdoor' ].name" -o tsv)
frontEndWebAppHostName=$(az afd endpoint list -g $resourceGroupName --profile-name $frontDoorProfileName --query "[].hostName" -o tsv --only-show-errors)
frontEndWebAppUri="https://$frontEndWebAppHostName"

substring="-rg"
secondaryResourceGroupName=(${resourceGroupName%%$substring*})
secondaryResourceGroupName+="-secondary-rg"
group2Exists=$(az group exists -n $secondaryResourceGroupName)
if [[ $group2Exists == 'false' ]]; then
    secondaryResourceGroupName=''
fi

# updated az resource selection to filter to first based on https://github.com/Azure/azure-cli/issues/25214
mySqlServer=$(az resource list -g $resourceGroupName --query "[?type=='Microsoft.Sql/servers'].name" -o tsv)

azdData=$(azd env get-values)
isProd=''
if [[ $azdData =~ 'IS_PROD="true"' ]]; then
  isProd=true
fi

echo "Derived inputs"
echo "----------------------------------------------"
if [[ $isProd ]]; then
  echo "isProd=true"
else
  echo "isProd=false"
fi
echo "keyVaultName=$keyVaultName"
echo "appConfigSvcName=$appConfigSvcName"
echo "frontEndWebAppUri=$frontEndWebAppUri"
echo "resourceToken=$resourceToken"
echo "environmentName=$environmentName"
echo "secondaryResourceGroupName=$secondaryResourceGroupName"
echo ""

if [[ ${#keyVaultName} -eq 0 ]]; then
  echo "FATAL ERROR: Could not find Key Vault resource. Confirm the --resourceGroupName is the one created by the `azd provision` command."  1>&2
  exit 7
fi

echo "Runtime values"
echo "----------------------------------------------"
frontEndWebAppName="$environmentName-$resourceToken-frontend"
apiWebAppName="$environmentName-$resourceToken-api"
maxNumberOfRetries=20

echo "frontEndWebAppName='$frontEndWebAppName'"
echo "apiWebAppName='$apiWebAppName'"
echo "maxNumberOfRetries=$maxNumberOfRetries"

tenantId=$(az account show --query "tenantId" -o tsv)

userObjectId=$(az account show --query "id" -o tsv)

echo "tenantId='$tenantId'"
echo ""

if [[ $debug ]]; then
    read -n 1 -r -s -p "Press any key to continue..."
    echo ''
    echo "..."
fi

# prod environments do not allow public network access, this must be changed before we can set values
if [[ $isProd ]]; then
  # Resolves permission constraint that prevents the deploymentScript from running this command
  # https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/134
  az sql server update -n $mySqlServer -g $resourceGroupName --set publicNetworkAccess="Disabled" > /dev/null
fi

frontEndWebObjectId=$(az ad app list --filter "displayName eq '$frontEndWebAppName'" --query "[].id" -o tsv)

if [[ ${#frontEndWebObjectId} -eq 0 ]]; then

    # this web app doesn't exist and must be created
    
    frontEndWebAppClientId=$(az ad app create \
        --display-name $frontEndWebAppName \
        --sign-in-audience AzureADMyOrg \
        --app-roles '[{ "allowedMemberTypes": [ "User" ], "description": "Relecloud Administrator", "displayName": "Relecloud Administrator", "isEnabled": "true", "value": "Administrator" }]' \
        --web-redirect-uris $frontEndWebAppUri/signin-oidc https://localhost:7227/signin-oidc \
        --enable-id-token-issuance \
        --query appId --output tsv)

    echo "frontEndWebAppClientId='$frontEndWebAppClientId'"

    if [[ ${#frontEndWebAppClientId} -eq 0 ]]; then
      echo "FATAL ERROR: Failed to create front-end app registration" 1>&2
      exit 8
    fi
   

    isWebAppCreated=0
    currentRetryCount=0
    while [ $isWebAppCreated -eq 0 ]
    do
      # assumes that we only need to create client secret if the app registration did not exist
      frontEndWebAppClientSecret=$(az ad app credential reset --id $frontEndWebAppClientId --query "password" -o tsv --only-show-errors 2> /dev/null)
      isWebAppCreated=${#frontEndWebAppClientSecret}
  
      currentRetryCount=$((currentRetryCount + 1))
      if [[ $currentRetryCount -gt $maxNumberOfRetries ]]; then
        echo "FATAL ERROR: Tried to create a client secret too many times" 1>&2
        exit 14
      fi

      if [[ $isWebAppCreated -eq 0 ]]; then
        echo "... trying to create clientSecret for front-end attempt #$currentRetryCount"
      else
        echo "... created clientSecret for front-end"
        echo ""
      fi

      # sleep until the app registration is created
      sleep 3
    done
    
    # prod environments do not allow public network access, this must be changed before we can set values
    if [[ $isProd ]]; then
        # open the app config so that the local user can access
        az appconfig update --name $appConfigSvcName --resource-group $resourceGroupName --enable-public-network true > /dev/null
        
        # open the key vault so that the local user can access
        az keyvault update --name $keyVaultName --resource-group $resourceGroupName  --public-network-access Enabled > /dev/null
    fi

    # save 'AzureAd:ClientSecret' to Key Vault
    az keyvault secret set --name 'AzureAd--ClientSecret' --vault-name $keyVaultName --value $frontEndWebAppClientSecret --only-show-errors > /dev/null
    echo "Set keyvault value for: 'AzureAd--ClientSecret'"

    # save 'AzureAd:TenantId' to App Config Svc
    az appconfig kv set --name $appConfigSvcName --key 'AzureAd:TenantId' --value $tenantId --yes --only-show-errors > /dev/null
    echo "Set appconfig value for: 'AzureAd:TenantId'"

    # save 'AzureAd:ClientId' to App Config Svc
    az appconfig kv set --name $appConfigSvcName --key 'AzureAd:ClientId' --value $frontEndWebAppClientId --yes --only-show-errors > /dev/null
    echo "Set appconfig value for: 'AzureAd:ClientId'"
    
    # prod environments do not allow public network access
    if [[ $isProd ]]; then
        # close the app config so that the local user cannot access
        az appconfig update --name $appConfigSvcName --resource-group $resourceGroupName --enable-public-network false > /dev/null
        
        # close the key vault so that the local user cannot access
        az keyvault update --name $keyVaultName --resource-group $resourceGroupName  --public-network-access Disabled > /dev/null
    fi
else
    echo "frontend app registration objectId=$frontEndWebObjectId already exists. Delete the '$frontEndWebAppName' app registration to recreate or reset the settings."
    frontEndWebAppClientId=$(az ad app show --id $frontEndWebObjectId --query "appId" -o tsv)
    echo "frontEndWebAppClientId='$frontEndWebAppClientId'"
    canSetSecondAzureLocation=2
fi

echo ""
echo "Finished app registration for front-end"
echo ""

apiObjectId=$(az ad app list --filter "displayName eq '$apiWebAppName'" --query "[].id" -o tsv)

if [[ ${#apiObjectId} -eq 0 ]]; then 
    # the api app registration does not exist and must be created
        
    apiWebAppClientId=$(az ad app create \
      --display-name $apiWebAppName \
      --sign-in-audience AzureADMyOrg \
      --app-roles '[{ "allowedMemberTypes": [ "User" ], "description": "Relecloud Administrator", "displayName": "Relecloud Administrator", "isEnabled": "true", "value": "Administrator" }]' \
      --query appId --output tsv)

    echo "apiWebAppClientId='$apiWebAppClientId'"

    # sleep until the app registration is created correctly
    isApiCreated=0
    currentRetryCount=0

    while [ $isApiCreated -eq 0 ]
    do
      apiObjectId=$(az ad app show --id $apiWebAppClientId --query id -o tsv 2> /dev/null)
      isApiCreated=${#apiObjectId}
      
      currentRetryCount=$((currentRetryCount + 1))
      if [[ $currentRetryCount -gt $maxNumberOfRetries ]]; then
          echo 'FATAL ERROR: Tried to create retrieve the apiObjectId too many times' 1>&2
          exit 15
      fi

      if [[ $isApiCreated -eq 0 ]]; then
        echo "... trying to retrieve apiObjectId attempt #$currentRetryCount"
      else
        echo "... retrieved apiObjectId='$apiObjectId'"
      fi

      sleep 3
    done

    # Expose an API by defining a scope
    # application ID URI will be clientId by default

    scopeName='relecloud.api'

    isScopeAdded=0
    currentRetryCount=0
    while [ $isScopeAdded -eq 0 ]
    do
      az rest \
          --method PATCH \
          --uri "https://graph.microsoft.com/v1.0/applications/$apiObjectId" \
          --headers 'Content-Type=application/json' \
          --body "{ identifierUris:[ 'api://$apiWebAppClientId' ], api: { oauth2PermissionScopes: [ { value: '$scopeName', adminConsentDescription: 'Relecloud API access', adminConsentDisplayName: 'Relecloud API access', id: 'c791b666-cc87-4904-bc9f-c5945e08ba8f', isEnabled: true, type: 'Admin' } ] } }" 2> /dev/null

      createdScope=$(az ad app show --id $apiWebAppClientId --query 'api.oauth2PermissionScopes[0].value' -o tsv 2> /dev/null)

      if [[ $createdScope == $scopeName ]]; then
        isScopeAdded=1
        echo "... added scope $scopeName"
      else
        currentRetryCount=$((currentRetryCount + 1))
        echo "... trying to add scope attempt #$currentRetryCount"
        if [[ $currentRetryCount -gt $maxNumberOfRetries ]]; then
            echo 'FATAL ERROR: Tried to set scopes too many times' 1>&2
            exit 16
        fi
      fi

      sleep 3 
    done

    echo "... assigned scope to api"

    permId=''
    currentRetryCount=0
    while [ ${#permId} -eq 0 ]
    do
      permId=$(az ad app show --id $apiWebAppClientId --query 'api.oauth2PermissionScopes[].id' -o tsv 2> /dev/null)

      if [[ ${#permId} -eq 0 ]]; then
        currentRetryCount=$((currentRetryCount + 1))
        echo "... trying to retrieve permId attempt #$currentRetryCount"

        if [[ $currentRetryCount -gt $maxNumberOfRetries ]]; then
            echo 'FATAL ERROR: Tried to retrieve permissionId too many times' 1>&2
            exit 17
        fi
      else
        echo "... retrieved permId=$permId"
      fi

      sleep 3
    done

    preAuthedAppApplicationId=$frontEndWebAppClientId

    # Preauthorize the front-end as a client to suppress scope requests
    authorizedApps=''
    currentRetryCount=0
    while [ ${#authorizedApps} -eq 0 ]
    do
      az rest  \
          --method PATCH \
          --uri "https://graph.microsoft.com/v1.0/applications/$apiObjectId" \
          --headers 'Content-Type=application/json' \
          --body "{api:{preAuthorizedApplications:[{appId:'$preAuthedAppApplicationId',delegatedPermissionIds:['$permId']}]}}" 2> /dev/null

      authorizedApps=$(az ad app show --id $apiObjectId --query "api.preAuthorizedApplications[].appId" -o tsv 2> /dev/null)

      if [[ ${#authorizedApps} -eq 0 ]]; then
        currentRetryCount=$((currentRetryCount + 1))
        echo "... trying to set front-end app as an preAuthorized client attempt #$currentRetryCount"

        if [[ $currentRetryCount -gt $maxNumberOfRetries ]]; then
            echo 'FATAL ERROR: Tried to authorize the front-end app too many times' 1>&2
            exit 18
        fi
      else
        echo "front-end web app is now preAuthorized"
        echo ""
      fi

      sleep 3
    done
    
    # prod environments do not allow public network access, this must be changed before we can set values
    if [[ $isProd ]]; then
        # open the app config so that the local user can access
        az appconfig update --name $appConfigSvcName --resource-group $resourceGroupName --enable-public-network true > /dev/null
    fi

    # save 'App:RelecloudApi:AttendeeScope' scope for role to App Config Svc
    az appconfig kv set --name $appConfigSvcName --key 'App:RelecloudApi:AttendeeScope' --value "api://$apiWebAppClientId/$scopeName" --yes --only-show-errors > /dev/null
    echo "Set appconfig value for: 'App:RelecloudApi:AttendeeScope'"

    # save 'Api:AzureAd:ClientId' to App Config Svc
    az appconfig kv set --name $appConfigSvcName --key 'Api:AzureAd:ClientId' --value $apiWebAppClientId --yes --only-show-errors > /dev/null
    echo "Set appconfig value for: 'Api:AzureAd:ClientId'"

    # save 'Api:AzureAd:TenantId' to App Config Svc
    az appconfig kv set --name $appConfigSvcName --key 'Api:AzureAd:TenantId' --value $tenantId --yes --only-show-errors > /dev/null
    echo "Set appconfig value for: 'Api:AzureAd:TenantId'"

    # prod environments do not allow public network access
    if [[ $isProd ]]; then
        # close the app config so that the local user cannot access
        az appconfig update --name $appConfigSvcName --resource-group $resourceGroupName --enable-public-network false > /dev/null
    fi
else
  echo "API app registration objectId=$apiObjectId already exists. Delete the '$apiWebAppName' app registration to recreate or reset the settings."
  canSetSecondAzureLocation=3
fi

############## Copy the App Configuration and Key Vault settings to second azure location ##############

if [[ ${#secondaryResourceGroupName} -gt 0 && $canSetSecondAzureLocation -eq 1 ]]; then
  
  # assumes there is only one vault deployed to this resource group that will match this filter
  secondaryKeyVaultName=$(az keyvault list -g "$secondaryResourceGroupName" --query "[?name.starts_with(@,'rc-')].name" -o tsv)

  secondaryAppConfigSvcName=$(az appconfig list -g "$secondaryResourceGroupName" --query "[].name" -o tsv)

  echo ""
  echo "Derived inputs for second azure location"
  echo "----------------------------------------------"
  echo "secondaryKeyVaultName=$secondaryKeyVaultName"
  echo "secondaryAppConfigSvcName=$secondaryAppConfigSvcName"

  if [[ ${#secondaryKeyVaultName} -eq 0 ]]; then
    echo "No secondary vault to configure"
    exit 0
  fi

  echo ""
  echo "Now configuring secondary key vault"

  # prod environments do not allow public network access, this must be changed before we can set values
  if [[ $isProd ]]; then
      # open the app config so that the local user can access
      az appconfig update --name $secondaryAppConfigSvcName --resource-group $secondaryResourceGroupName --enable-public-network true > /dev/null
      
      # open the key vault so that the local user can access
      az keyvault update --name $secondaryKeyVaultName --resource-group $secondaryResourceGroupName  --public-network-access Enabled > /dev/null
  fi

  # save 'AzureAd:ClientSecret' to Key Vault
  az keyvault secret set --name 'AzureAd--ClientSecret' --vault-name $secondaryKeyVaultName --value $frontEndWebAppClientSecret --only-show-errors > /dev/null
  echo "... Set keyvault value for: 'AzureAd--ClientSecret'"

  echo ""
  echo "Now configuring secondary app config svc"
  # save 'AzureAd:TenantId' to App Config Svc
  az appconfig kv set --name $secondaryAppConfigSvcName --key 'AzureAd:TenantId' --value $tenantId --yes --only-show-errors > /dev/null
  echo "... Set appconfig value for: 'AzureAd:TenantId'"

  #save 'AzureAd:ClientId' to App Config Svc
  az appconfig kv set --name $secondaryAppConfigSvcName --key 'AzureAd:ClientId' --value $frontEndWebAppClientId --yes --only-show-errors > /dev/null
  echo "... Set appconfig value for: 'AzureAd:ClientId'"
  
  # save 'App:RelecloudApi:AttendeeScope' scope for role to App Config Svc
  az appconfig kv set --name $secondaryAppConfigSvcName --key 'App:RelecloudApi:AttendeeScope' --value "api://$apiWebAppClientId/$scopeName" --yes --only-show-errors > /dev/null
  echo "... Set appconfig value for: 'App:RelecloudApi:AttendeeScope'"

  # save 'Api:AzureAd:ClientId' to App Config Svc
  az appconfig kv set --name $secondaryAppConfigSvcName --key 'Api:AzureAd:ClientId' --value $apiWebAppClientId --yes --only-show-errors > /dev/null
  echo "... Set appconfig value for: 'Api:AzureAd:ClientId'"
    
  # save 'Api:AzureAd:TenantId' to App Config Svc
  az appconfig kv set --name $secondaryAppConfigSvcName --key 'Api:AzureAd:TenantId' --value $tenantId --yes --only-show-errors > /dev/null
  echo "... Set appconfig value for: 'Api:AzureAd:TenantId'"

  # prod environments do not allow public network access
  if [[ $isProd ]]; then
      # close the app config so that the local user cannot access
      az appconfig update --name $secondaryAppConfigSvcName --resource-group $secondaryResourceGroupName --enable-public-network false > /dev/null
      
      # close the key vault so that the local user cannot access
      az keyvault update --name $secondaryKeyVaultName --resource-group $secondaryResourceGroupName  --public-network-access Disabled > /dev/null
  fi

elif [[ $canSetSecondAzureLocation -eq 2 ]]; then
  echo ""
  echo "skipped setup for secondary azure location because frontend app registration objectId=$frontEndWebObjectId already exists."
elif [[ $canSetSecondAzureLocation -eq 3 ]]; then
  echo ""
  echo "skipped setup for secondary location because API app registration objectId=$apiObjectId already exists."
fi

# all done
exit 0
