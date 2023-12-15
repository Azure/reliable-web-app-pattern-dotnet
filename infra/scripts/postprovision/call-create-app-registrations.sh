#!/bin/bash

# This script is run by azd pre-provision hook and is part of the deployment lifecycle run when deploying the code for the Relecloud web app.
resourceGroupName=$((azd env get-values --output json) | jq -r .AZURE_RESOURCE_GROUP)

echo "Calling create-app-registrations.ps1 for group:'resourceGroupName'..."

pwsh ./infra/scripts/postprovision/create-app-registrations.ps1 -ResourceGroupName $resourceGroupName -NoPrompt