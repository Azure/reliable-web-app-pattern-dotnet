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
else
   echo "No appconfig to purge"
fi

deletedKeyVaultSvcName=$(az keyvault list-deleted --query "[? properties.vaultId.contains(@,'$resourceGroupName')] | [0].name" -o tsv)
currentRetryCount=0

while [ ${#deletedKeyVaultSvcName} -ne 0 ]
do
  if [[ $currentRetryCount -gt 6 ]]; then
    echo "FATAL ERROR: Tried to purge key vault too many times" 1>&2
    exit 14
  fi

  if [[ ${#deletedKeyVaultSvcName} -gt 0 ]]; then
    echo "Purging $deletedKeyVaultSvcName"
    az keyvault purge --name $deletedKeyVaultSvcName
  else
    echo "Done purging key vaults"
  fi

  currentRetryCount=$((currentRetryCount + 1))
  deletedKeyVaultSvcName=$(az keyvault list-deleted --query "[? properties.vaultId.contains(@,'$resourceGroupName')] | [0].name" -o tsv)
done