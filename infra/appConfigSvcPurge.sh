#!/bin/bash

# This script is a workaround to a known issue

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --resourceToken)
      resourceToken="$2"
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
echo "resourceToken=$resourceToken"
echo ""

deletedAppConfigSvcName=$(az appconfig list-deleted --query "[?starts_with(name, '$resourceToken')].name" -o tsv)

if [[ ${#deletedAppConfigSvcName} -gt 0 ]]; then
  az appconfig purge --name $deletedAppConfigSvcName --yes
  echo "Purged $deletedAppConfigSvcName"
  sleep 3 # give Azure some time to propagate this event
else
  echo "Nothing to purge"
fi
