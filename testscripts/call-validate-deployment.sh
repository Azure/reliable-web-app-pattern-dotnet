#!/bin/bash

# This script is run by GitHub workflow and is part of the deployment lifecycle run when validatinng the deployment for the Relecloud web app.
resourceGroupName=$((azd env get-values --output json) | jq -r .AZURE_RESOURCE_GROUP)
echo "Calling validate-deployment.sh for group:'$resourceGroupName'..."
./testscripts/validate-deployment.sh -g $resourceGroupName