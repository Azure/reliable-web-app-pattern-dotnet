#!/bin/bash

# This script validates the parameters for the deployment of the Azure DevOps environment.

# The script retrieves the configuration values from Azure DevOps and validates the environment type and network isolation settings.
# It checks if the environment type is either 'dev' or 'prod' and if the network isolation is enabled for the 'prod' environment type.
# If any of the parameters are invalid, an error message is displayed and the script exits with a non-zero status code.

# This script requires the Azure CLI to be installed and logged in to Azure DevOps.
# The configuration values are retrieved using the 'azd env get-values' command.

# Example usage: ./validate-params.sh

environmentType=$(azd env get-values -o json | jq -r '.ENVIRONMENT')

# default environmentType to dev if not set
if [[ $environmentType == "null" ]]; then
    environmentType="dev"
fi

# Block invalid deployment scenarios by helping the user understand the valid AZD options
if [[ $environmentType != "dev" && $environmentType != "prod" ]]; then
    echo ""
    echo "   Invalid AZD environment type: '$environmentType'. Valid values are 'dev' or 'prod'."
    exit 1
fi