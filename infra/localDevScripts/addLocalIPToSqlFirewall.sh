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
      echo "    addLocalIPToSqlFirewall.sh : Makes a web request to a public site to retrieve the user's public IP address and then adds that IP address to the Azure SQL Database Firewall as an allowed connection."
      echo ""
      echo "Arguments"
      echo "    --resource-group -g : Name of resource group containing the environment that was created by the azd command."
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
  printf "${red}FATAL ERROR:${clear} Missing required parameter --resource-group"
  echo ""

  exit 6
fi

myIpAddress=$(wget -q -O - ipinfo.io/ip)
# updated az resource selection to filter to first based on https://github.com/Azure/azure-cli/issues/25214
mySqlServer=$(az resource list -g $resourceGroupName --query "[?type=='Microsoft.Sql/servers'].name " -o tsv)

# Resolves permission constraint that prevents the deploymentScript from running this command
# https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/134
az sql server update -n $mySqlServer -g $resourceGroupName --set publicNetworkAccess="Enabled" > /dev/null

az sql server firewall-rule create -g $resourceGroupName -s $mySqlServer -n "devbox_$(date +"%Y-%m-%d_%I-%M-%S")" --start-ip-address $myIpAddress --end-ip-address $myIpAddress
