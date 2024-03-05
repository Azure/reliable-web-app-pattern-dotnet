#!/bin/bash

# if this is CI/CD then we want to skip this step because the app registrations already exist
principalType=$((azd env get-values --output json) | jq -r .AZURE_PRINCIPAL_TYPE)

if [ "$principalType" == "ServicePrincipal" ]; then
    echo "Skipping create-app-registrations.ps1 because principalType is ServicePrincipal"
    exit 0
fi

# This script is run by azd pre-provision hook and is part of the deployment lifecycle run when deploying the code for the Relecloud web app.
resourceGroupName=$((azd env get-values --output json) | jq -r .AZURE_RESOURCE_GROUP)

echo "Calling create-app-registrations.ps1 for group:'resourceGroupName'..."

pwsh ./infra/scripts/postprovision/create-app-registrations.ps1 -ResourceGroupName $resourceGroupName -NoPrompt