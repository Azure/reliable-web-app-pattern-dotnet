#!/bin/bash

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --resource-group|-g)
      resourceGroupName="$2"
      shift # past argument
      shift # past value
      ;;
    --help*)
      echo ""
      echo "<This command should only be run after using the azd command to deploy resources to Azure>"
      echo ""
      echo "Command"
      echo "    giveCurrentUserAccessToReadAppConfigSvc.sh : This script supports the local development scenario by giving the current user RBAC access to the"
      echo "              Azure App Configuration Service that was deployed by the AZD command in a previous step. The role '516239f1-63e1-4d78-a4de-a74fb236a071'"
      echo "              is a well-known role from the list of Azure RBAC roles"
      echo "              https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#app-configuration-data-reader"
      echo ""
      echo "Arguments"
      echo "    --resource-group -g : Name of resource group where this Redis Cache is deployed."
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

appConfigDataReaderRole='516239f1-63e1-4d78-a4de-a74fb236a071'
currentUserObjectId=$(az ad signed-in-user show --query "id")
scopeId=$(az group show -n $resourceGroupName --query "id")
az role assignment create --role $appConfigDataReaderRole --assignee ${currentUserObjectId:1:-2} --scope ${scopeId:1:-2}