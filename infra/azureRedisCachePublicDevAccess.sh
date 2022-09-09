#!/bin/bash

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --name|-n)
      redisCacheName="$2"
      shift # past argument
      shift # past value
      ;;
    --resource-group|-g)
      resourceGroupName="$2"
      shift # past argument
      shift # past value
      ;;
    --subscription|-s)
      subscriptionId="$2"
      shift # past argument
      shift # past value
      ;;
    --help*)
      echo ""
      echo "<This command should only be run after using the azd command to deploy resources to Azure>"
      echo ""
      echo "Command"
      echo "    azureRedisCachePublicDevAccess.sh : is used by devs to make Redis accessible for non-prod dev tasks"
      echo ""
      echo "Arguments"
      echo "    --resource-group -g : Name of resource group where this Redis Cache is deployed."
      echo "    --subscription   -s : The subscriptionId where this Redis Cache is deployed."
      echo "    --name           -n : Name of the Redis Cache that should be modified."
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

if [[ ${#subscriptionId} -eq 0 ]]; then
  echo "FATAL ERROR: Missing required parameter --subscription" 1>&2
  exit 7
fi

if [[ ${#redisCacheName} -eq 0 ]]; then
  echo "FATAL ERROR: Missing required parameter --name" 1>&2
  exit 8
fi

az rest \
    --method PATCH \
    --uri "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Cache/Redis/$redisCacheName?api-version=2020-06-01" \
    --headers 'Content-Type=application/json' \
    --body "{ \"properties\": { \"publicNetworkAccess\":\"Enabled\" } }"