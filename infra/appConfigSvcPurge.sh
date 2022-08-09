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

echo "Inputs"
echo "----------------------------------------------"
echo "appcfgname=$appcfgname"
echo "----------------------------------------------"

# deletedAppConfigSvcName=$(az appconfig list-deleted --query "[?name=='$appcfgname'].name" -o tsv)

# if [[ ${#deletedAppConfigSvcName} -gt 0 ]]; then
  az appconfig purge --name $appcfgname --yes
  echo "Purged $appcfgname"  
  sleep 3 # give Azure some time to propagate this event
# else
#   echo "Nothing to purge"
# fi
