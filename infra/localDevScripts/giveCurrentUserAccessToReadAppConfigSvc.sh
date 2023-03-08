#!/bin/bash

# This script is part of the sample's workflow for giving developers access
# to the resources that were deployed. Note that a better solution, beyond
# the scope of this demo, would be to associate permissions based on
# Azure AD groups so that all team members inherit access from Azure AD.
# https://learn.microsoft.com/en-us/azure/active-directory/roles/groups-concept
#
# This code may be repurposed for your scenario as desired
# but is not covered by the guidance in this content.

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
      echo "    --resource-group -g : Name of the resource group that was created by azd."
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
currentUserObjectId=$(az ad signed-in-user show --query "id" | tr -d '"')
scopeId=$(az group show -n $resourceGroupName --query "id" | tr -d '"')
az role assignment create --role $appConfigDataReaderRole --assignee $currentUserObjectId --scope $scopeId