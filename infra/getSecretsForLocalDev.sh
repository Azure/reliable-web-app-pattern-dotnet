#!/bin/bash

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
    --secondary-resource-group|-sg)
      secondaryResourceGroupName="$2"
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
      echo "    --resource-group -g : Name of resource group containing the environment that was creaed by the azd command."
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
  echo 'FATAL ERROR: Missing required parameter --resource-group' 1>&2
  exit 6
fi

if [[ $web_app && $api_app ]]; then
  echo 'FATAL ERROR: Missing required flag --web or --api' 1>&2
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
keyVaultName=$(az keyvault list -g "$resourceGroupName" --query "[?name.starts_with(@,'rc-')].name" -o tsv)

appConfigSvcName=$(az appconfig list -g "$resourceGroupName" --query "[].name" -o tsv)

if [[ $debug ]]; then
    echo "Derived inputs"
    echo "----------------------------------------------"
    echo "keyVaultName=$keyVaultName"
    echo "appConfigSvcName=$appConfigSvcName"
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
    frontEndBaseUri=$(az appconfig kv show -n $appConfigSvcName --key App:RelecloudApi:BaseUri -o tsv --query value 2> /dev/null) 

    # get 'AzureAd:ClientId' from App Configuration svc
    frontEndAzureAdClientId=$(az appconfig kv show -n $appConfigSvcName --key AzureAd:ClientId -o tsv --query value 2> /dev/null) 

    # get 'AzureAd:TenantId' from App Configuration svc
    frontEndAzureAdTenantId=$(az appconfig kv show -n $appConfigSvcName --key AzureAd:TenantId -o tsv --query value 2> /dev/null) 

    echo ""
    echo "{"
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

    # App:StorageAccount:QueueConnectionString
    apiAppQueueConnStr=$(az keyvault secret show --vault-name $keyVaultName --name App--StorageAccount--QueueConnectionString -o tsv --query "value" 2> /dev/null) 

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
    echo "   \"Api:AzureAd:ClientId\": \"$apiAppAzureAdClientId\","
    echo "   \"Api:AzureAd:TenantId\": \"$apiAppAzureAdTenantId\","
    echo "   \"App:RedisCache:ConnectionString\": \"$apiAppRedisConnStr\","
    echo "   \"App:SqlDatabase:ConnectionString\": \"$apiAppSqlConnStr\","
    echo "   \"App:StorageAccount:QueueConnectionString\": \"$apiAppQueueConnStr\""
    echo "}"
    echo ""
fi
