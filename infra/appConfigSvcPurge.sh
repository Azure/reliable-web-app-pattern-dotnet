#!/bin/bash

# This script is a workaround to a known issue

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --appcfgname)
      appcfgname="$2"
      shift # past argument
      shift # past value
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

echo -e "Inputs\n"
echo -e "----------------------------------------------\n"
echo -e "appcfgname=$appcfgname\n"
echo -e "\n"

deletedAppConfigSvcName=$(az appconfig list-deleted --query "[?name=='$appcfgname'].name" -o tsv)

if [[ ${#deletedAppConfigSvcName} -gt 0 ]]; then
  az appconfig purge --name $deletedAppConfigSvcName --yes
  echo "Purged $deletedAppConfigSvcName"  
  sleep 3 # give Azure some time to propagate this event
else
  echo "Nothing to purge"
fi
