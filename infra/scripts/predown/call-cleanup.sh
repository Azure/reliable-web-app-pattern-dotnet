#!/bin/bash

# This script will be run by the Azure Developer CLI, and will have access to the AZD_* vars
# This calls the cleanup.ps1 script with the correct AZD resource group.

# This script will be run by the Azure Developer CLI, and will remove resources
# that are not deleted as part of the `azd down` command such as the following:
# - App registrations
# - Azure budgets
# - Azure diagnostic settings
# Script also deletes private endpoints.
# Depends on the AZURE_RESOURCE_GROUP environment variable being set. AZD requires this to
# understand which resource group to deploy to so this script uses it to learn about the
# environment where the configuration settings should be set.

resourceGroupName=$(azd env get-values --output json | jq -r '.AZURE_RESOURCE_GROUP')

# if the resource group equals the string 'null', then exit
if [ "$resourceGroupName" == "null" ]; then
  echo "AZURE_RESOURCE_GROUP not set..."
  exit 0
fi


echo "Calling cleanup.ps1 for group:'$resourceGroupName'..."

pwsh ./testscripts/cleanup.ps1 -ResourceGroup "$resourceGroupName" -NoPrompt -Purge
