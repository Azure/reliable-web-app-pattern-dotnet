#!/bin/bash

# This script is part of the sample's workflow for giving developers access
# to the resources that were deployed. Note that a better solution, beyond
# the scope of this demo, would be to associate permissions based on
# Azure AD groups so that all team members inherit access from Azure AD.
# https://learn.microsoft.com/en-us/azure/active-directory/roles/groups-concept
#
# This code may be repurposed for your scenario as desired
# but is not covered by the guidance in this content.

web_app=''
api_app=''
debug=''

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --resource-group|-g)
      resourceGroupName="$2"
      shift # past argument
      shift # past value
      ;;
    --web|-w)
      web_app=true
      shift # past argument
      ;;
    --api|-a)
      api_app=true
      shift # past argument
      ;;
    --debug)
      debug=true
      shift # past argument
      ;;
    --help*)
      echo ""
      echo "<This command should only be run after using the azd command to deploy resources to Azure>"
      echo ""
      echo "Command"
      echo "    getSecretsForLocalDev.sh : Will show a json snippet you can save in Visual Studio secrets.json file to run the code locally."
      echo ""
      echo "Arguments"
      echo "    --resource-group -g : Name of resource group containing the environment that was created by the azd command."
      echo ""
      echo " Must select one or more of the following flags"
      echo "    --api -a : Print the json snippet for the api web app. Defaults to False."
      echo "    --web -w : Print the json snippet for the front-end web app. Defaults to False."
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
  printf "${red}FATAL ERROR:${clear} Missing required parameter --resource-group"
  echo ""

  exit 6
fi

if [[ $web_app == '' && $api_app == '' ]]; then
  printf "${red}FATAL ERROR:${clear} Missing required flag --web or --api"
  echo ""

  exit 7
fi

if [[ $debug ]]; then
    echo ""
    echo "Inputs"
    echo "----------------------------------------------"
    echo "resourceGroupName='$resourceGroupName'"
    echo ""
fi

# assumes there is only one vault deployed to this resource group that will match this filter
keyVaultName=$(az keyvault list -g "$resourceGroupName" --query "[?name.starts_with(@,'rc-')].name " -o tsv)

appConfigSvcName=$(az resource list -g $resourceGroupName --query "[?type=='Microsoft.AppConfiguration/configurationStores'].name " -o tsv)

appConfigUri=$(az appconfig show -n $appConfigSvcName -g $resourceGroupName --query "endpoint" -o tsv  2> /dev/null)

if [[ $debug ]]; then
    echo "Derived inputs"
    echo "----------------------------------------------"
    echo "keyVaultName=$keyVaultName"
    echo "appConfigSvcName=$appConfigSvcName"
    
    read -n 1 -r -s -p "Press any key to continue..."
    echo ''
    echo "..."
fi

###
# Step1: Print json snippet for web app
###

if [[ $web_app ]]; then
    # get 'AzureAd:ClientSecret' from Key Vault
    frontEndAzureAdClientSecret=$(az keyvault secret show --vault-name $keyVaultName --name AzureAd--ClientSecret -o tsv --query "value" 2> /dev/null) 
    
    # get 'App:RedisCache:ConnectionString' from Key Vault
    frontEndRedisConnStr=$(az keyvault secret show --vault-name $keyVaultName --name App--RedisCache--ConnectionString -o tsv --query "value" 2> /dev/null) 

    # get 'App:RelecloudApi:AttendeeScope' from App Configuration Svc
    frontEndAttendeeScope=$(az appconfig kv show -n $appConfigSvcName --key App:RelecloudApi:AttendeeScope -o tsv --query value 2> /dev/null) 

    # get 'App:RelecloudApi:BaseUri' from App Configuration svc
    # frontEndBaseUri=$(az appconfig kv show -n $appConfigSvcName --key App:RelecloudApi:BaseUri -o tsv --query value 2> /dev/null) 
    frontEndBaseUri="https://localhost:7242"

    # get 'AzureAd:ClientId' from App Configuration svc
    frontEndAzureAdClientId=$(az appconfig kv show -n $appConfigSvcName --key AzureAd:ClientId -o tsv --query value 2> /dev/null) 

    # get 'AzureAd:TenantId' from App Configuration svc
    frontEndAzureAdTenantId=$(az appconfig kv show -n $appConfigSvcName --key AzureAd:TenantId -o tsv --query value 2> /dev/null) 

    echo ""
    echo "{"
    echo "   \"App:AppConfig:Uri\": \"$appConfigUri\","
    echo "   \"App:RedisCache:ConnectionString\": \"$frontEndRedisConnStr\","
    echo "   \"App:RelecloudApi:AttendeeScope\": \"$frontEndAttendeeScope\","
    echo "   \"App:RelecloudApi:BaseUri\": \"$frontEndBaseUri\","
    echo "   \"AzureAd:ClientId\": \"$frontEndAzureAdClientId\","
    echo "   \"AzureAd:ClientSecret\": \"$frontEndAzureAdClientSecret\","
    echo "   \"AzureAd:TenantId\": \"$frontEndAzureAdTenantId\""
    echo "}"
    echo ""
fi


if [[ $api_app ]]; then

    # App:StorageAccount:ConnectionString
    apiAppQueueConnStr=$(az keyvault secret show --vault-name $keyVaultName --name App--StorageAccount--ConnectionString -o tsv --query "value" 2> /dev/null) 

    # get 'App:RedisCache:ConnectionString' from Key Vault
    apiAppRedisConnStr=$(az keyvault secret show --vault-name $keyVaultName --name App--RedisCache--ConnectionString -o tsv --query "value" 2> /dev/null) 

    # get 'Api:AzureAd:ClientId' from App Configuration svc
    apiAppAzureAdClientId=$(az appconfig kv show -n $appConfigSvcName --key Api:AzureAd:ClientId -o tsv --query value 2> /dev/null) 

    # get 'Api:AzureAd:TenantId' from App Configuration svc
    apiAppAzureAdTenantId=$(az appconfig kv show -n $appConfigSvcName --key Api:AzureAd:TenantId -o tsv --query value 2> /dev/null) 

    # App:SqlDatabase:ConnectionString
    apiAppSqlConnStr=$(az appconfig kv show -n $appConfigSvcName --key App:SqlDatabase:ConnectionString -o tsv --query value 2> /dev/null) 

    echo ""
    echo "{"
    echo "   \"Api:AppConfig:Uri\": \"$appConfigUri\","
    echo "   \"Api:AzureAd:ClientId\": \"$apiAppAzureAdClientId\","
    echo "   \"Api:AzureAd:TenantId\": \"$apiAppAzureAdTenantId\","
    echo "   \"App:RedisCache:ConnectionString\": \"$apiAppRedisConnStr\","
    echo "   \"App:SqlDatabase:ConnectionString\": \"$apiAppSqlConnStr\","
    echo "   \"App:StorageAccount:QueueConnectionString\": \"$apiAppQueueConnStr\""
    echo "}"
    echo ""
fi
