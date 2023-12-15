#!/bin/bash

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --resource-group|-g)
      resourceGroupName="$2"
      shift # past argument
      shift # past value
      ;;
    --debug)
      debug=true
      shift # past argument
      ;;
    --help*)
      echo ""
      echo "<This command should only be run after using the azd command to deploy resources to Azure>"
      echo ""
      echo "Command"
      echo "    validateDeployment.sh  : Use this command to troubleshoot your deployment."
      echo ""
      echo "Arguments"
      echo "    --resource-group    -g : Name of resource group containing the environment that was created by the azd command."
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
  echo 'FATAL ERROR: Missing required parameter --resource-group' 1>&2
  exit 6
fi

if [[ $resourceGroupName = '-rg' ]]; then
  echo 'FATAL ERROR: Required parameter --resource-group was not initialized' 1>&2
  exit 7
fi

### check if group exists ###

groupExists=$(az group exists -n $resourceGroupName)
if [[ $groupExists = 'false' ]]; then
    echo "Missing required resource group. The resource group '$resourceGroupName' does not exist" 1>&2
    echo "Recommended Action: run the 'azd provision' command again to overlay the missing settings"
    exit 32
elif [[ $debug ]]; then
    echo "Validated that the resource group does exist"
fi

### end check group exists ###


### validate web app settings ###

# checking for known issue 87
# https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/87


for appTag in web-call-center call-center-api public-api web-public; do

  appName=$(az resource list -g "$resourceGroupName" --query "[?tags.\"azd-service-name\"=='${appTag}'].name" -o tsv)

  if [[ ${#appName} -eq 0 ]]; then
      echo "Cannot find the app with tag: $appTag" 1>&2
      echo "Recommended Action: run the 'azd provision' command again to overlay the missing settings" 1>&2
      exit 32
  elif [[ $debug ]]; then
      echo "Found app with tag: '$appTag', appName: '$appName' "
  fi

  # Determine which appConfig key we are looking for depending on api versus web flavor of our application
  if [[ $appTag == *"api"* ]];
  then
      appSettingConfig="Api:AppConfig:Uri"
  else
      appSettingConfig="App:AppConfig:Uri"
  fi

  appUri=$(az webapp config appsettings list -n $appName -g $resourceGroupName --query "[?name=='$appSettingConfig'].value" -o tsv)

  if [[ ${#appUri} -eq 0 ]]; then
    echo "Missing required Azure App Service configuration setting $appSettingConfig in app: $appName" 1>&2
    echo "Recommended Action: run the 'azd provision' command again to overlay the missing settings" 1>&2
    exit 33
  elif [[ $debug ]]; then
      echo "Validated that the App Service was configured with setting '$appSettingConfig' equal to '$appUri'"
  fi

done

# end of check for issue 87


echo "All settings validated successfully..."
echo "If this script was unable to diagnose your problem then please create a GitHub issue"
exit 0
