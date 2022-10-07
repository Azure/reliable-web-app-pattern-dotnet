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
      echo "    addLocalIPToSqlFirewall.sh : Makes a web request to a public site to retrieve the user's public IP address and then adds that IP address to the Azure SQL Database Firewall as an allowed connection."
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

myIpAddress=$(wget -q -O - ipinfo.io/ip)
mySqlServer=$(az resource list -g $resourceGroupName --query "[?type=='Microsoft.Sql/servers'].name" -o tsv)
az sql server firewall-rule create -g $resourceGroupName -s $mySqlServer -n "devbox_$(date +"%Y-%m-%d_%I-%M-%S")" --start-ip-address $myIpAddress --end-ip-address $myIpAddress

#### support multi-regional deployment ####

substring="-rg"
secondaryResourceGroupName=(${resourceGroupName%%$substring*})
secondaryResourceGroupName+="-secondary-rg"
group2Exists=$(az group exists -n $secondaryResourceGroupName)
if [[ $group2Exists -eq 'false' ]]; then
    secondaryResourceGroupName=''
fi


if [[ ${#secondaryResourceGroupName} -gt 0 ]]; then
  mySqlServer=$(az resource list -g $secondaryResourceGroupName --query "[?type=='Microsoft.Sql/servers'].name" -o tsv)
  az sql server firewall-rule create -g $secondaryResourceGroupName -s $mySqlServer -n "devbox_$(date +"%Y-%m-%d_%I-%M-%S")" --start-ip-address $myIpAddress --end-ip-address $myIpAddress

fi