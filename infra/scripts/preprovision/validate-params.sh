#!/bin/bash

# This script validates the parameters for the deployment of the Azure DevOps environment.

# The script retrieves the configuration values from Azure DevOps and validates the environment type and network isolation settings.
# It checks if the environment type is either 'dev' or 'prod' and if the network isolation is enabled for the 'prod' environment type.
# If any of the parameters are invalid, an error message is displayed and the script exits with a non-zero status code.

# This script requires the Azure CLI to be installed and logged in to Azure DevOps.
# The configuration values are retrieved using the 'azd env get-values' command.

# Example usage: ./validate-params.sh

environmentType=$(azd env get-values -o json | jq -r '.AZURE_ENV_TYPE')
networkIsolation=$(azd env get-values -o json | jq -r '.NETWORK_ISOLATION')

# default environmentType to dev if not set
if [[ $environmentType == "null" ]]; then
    environmentType="dev"
fi

# default networkIsolation to false if not set
if [[ $networkIsolation == "null" ]]; then
    networkIsolation="false"
fi

# Block invalid deployment scenarios by helping the user understand the valid AZD options
if [[ $environmentType != "dev" && $environmentType != "prod" ]]; then
    echo ""
    echo "   Invalid AZD environment type: '$environmentType'. Valid values are 'dev' or 'prod'."
    exit 1
fi

if [[ $networkIsolation == "false" && $environmentType != "dev" ]]; then
    echo ""
    echo "   Invalid AZD network isolation value: '$networkIsolation' and AZD environment type: '$environmentType'. The 'prod' environment type can only be used when network isolation is enabled."
    exit 1
fi
