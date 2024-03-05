#!/bin/bash

# This script is run by azd pre-provision hook and is part of the deployment lifecycle run when deploying the code for the Relecloud web app.
resourceGroupName=$((azd env get-values --output json) | jq -r .AZURE_RESOURCE_GROUP)
webUri=$((azd env get-values --output json) | jq -r .WEB_URI)

echo "Calling set-app-configuration.ps1 for group:'$resourceGroupName' with webUri:'$webUri' ..."

pwsh ./infra/scripts/predeploy/set-app-configuration.ps1 -ResourceGroupName $resourceGroupName -WebUri $webUri  -NoPrompt