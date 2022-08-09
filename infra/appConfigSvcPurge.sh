#!/bin/bash

# This script is a temporary workaround to a known issue
# Executed from Github workflow it will handle purging soft-deleted Azure App Configuration Service instances
# https://github.com/Azure/azure-dev/issues/248

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --resource-group|-g)
      resourceGroupName="$2"
      shift # past argument
      shift # past value
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

echo "Inputs"
echo "----------------------------------------------"
echo "resourceGroupName=$resourceGroupName"
echo "----------------------------------------------"

deletedAppConfigSvcName=$(az appconfig list-deleted --query "[?configurationStoreId.contains(@,'$resourceGroupName')].name" -o tsv)

if [[ ${#deletedAppConfigSvcName} -gt 0 ]]; then
  az appconfig purge --name $deletedAppConfigSvcName --yes
  echo "Purged $deletedAppConfigSvcName"  
  sleep 3 # give Azure some time to propagate this event
else
   echo "Nothing to purge"
fi
