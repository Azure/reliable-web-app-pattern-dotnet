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
# https://github.com/Azure/scalable-web-app-pattern-dotnet/issues/87

frontEndWebAppName=$(az resource list -g "$resourceGroupName" --query "[?tags.\"azd-service-name\"=='web'].name" -o tsv)

if [[ ${#frontEndWebAppName} -eq 0 ]]; then
    echo "Cannot find the front-end web app" 1>&2
    echo "Recommended Action: run the 'azd provision' command again to overlay the missing settings" 1>&2
    exit 32
elif [[ $debug ]]; then
    echo "Found front-end web app named '$frontEndWebAppName' "
fi

frontEndAppSvcUri=$(az webapp config appsettings list -n $frontEndWebAppName -g $resourceGroupName --query "[?name=='App:AppConfig:Uri'].value" -o tsv)

if [[ ${#frontEndAppSvcUri} -eq 0 ]]; then
    echo "Missing required Azure App Service configuration setting front-end web app: App:AppConfig:Uri" 1>&2
    echo "Recommended Action: run the 'azd provision' command again to overlay the missing settings" 1>&2
    exit 33
elif [[ $debug ]]; then
    echo "Validated that the App Service was configured with setting 'App:AppConfig:Uri' equal to '$frontEndAppSvcUri'"
fi

apiWebAppName=$(az resource list -g "$resourceGroupName" --query "[?tags.\"azd-service-name\"=='api'].name" -o tsv)

if [[ ${#apiWebAppName} -eq 0 ]]; then
    echo "Cannot find the API web app" 1>&2
    echo "Recommended Action: run the 'azd provision' command again to overlay the missing settings" 1>&2
    exit 34
elif [[ $debug ]]; then
    echo "Found API web app named '$apiWebAppName'"
fi

apiAppSvcUri=$(az webapp config appsettings list -n $apiWebAppName -g $resourceGroupName --query "[?name=='Api:AppConfig:Uri'].value" -o tsv)

if [[ ${#apiAppSvcUri} -eq 0 ]]; then
    echo "Missing required Azure App Service configuration setting for api web app: Api:AppConfig:Uri" 1>&2
    echo "Recommended Action: run the 'azd provision' command again to overlay the missing settings"
    exit 35
elif [[ $debug ]]; then
    echo "Validated that the App Service was configured with setting 'Api:AppConfig:Uri' equal to '$apiAppSvcUri'"
fi

# end of check for issue 87


echo "All settings validated successfully..."
echo "If this script was unable to diagnose your problem then please create a GitHub issue"
exit 0
