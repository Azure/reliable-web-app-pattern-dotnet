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
    --debug)
      debug=true
      shift # past argument
      ;;
    --help*)
      echo ""
      echo "<This command should only be run after using the azd command to deploy resources to Azure>"
      echo ""
      echo "Command"
      echo "    makeSqlUserAccount.sh  : Will make the SQL user account required to authenticate with Azure AD to Azure SQL Database."
      echo ""
      echo "Arguments"
      echo "    --resource-group    -g : Name of resource group containing the environment that was created by the azd command."
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

# this will reset the SQL password because the password is not saved during set up
echo "WARNING: this script will reset the password for the SQL Admin on Azure SQL Server."
echo "  Since this scenario uses Managed Identity, and no one accesses the database with this password, there should be no impact"
echo "Use command interrupt if you would like to abort"
read -n 1 -r -s -p "Press any key to continue..."
echo ''
echo "..."

if ! [ -x "$(command -v ./sqlcmd)" ]; then
    echo 'installing sqlcmd'
    
    wget https://github.com/microsoft/go-sqlcmd/releases/download/v0.9.1/sqlcmd-v0.9.1-linux-x64.tar.bz2
    tar x -f sqlcmd-v0.9.1-linux-x64.tar.bz2
    
else
    echo 'found sqlcmd'
fi

azureAdUsername=$(az ad signed-in-user show --query userPrincipalName -o tsv)

objectIdForCurrentUser=$(az ad signed-in-user show --query id -o tsv)

# using json format bypasses issue with tsv format observed in this issue
# https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/202
databaseServer=$(az resource list -g $resourceGroupName --query "[? type=='Microsoft.Sql/servers'].name" -o tsv)

databaseServerFqdn=$(az sql server show -n $databaseServer -g $resourceGroupName --query fullyQualifiedDomainName  -o tsv)

# updated az resource selection to filter to first based on https://github.com/Azure/azure-cli/issues/25214
databaseName=$(az resource list -g $resourceGroupName --query "[?type=='Microsoft.Sql/servers/databases' && name.ends_with(@, 'database')].tags.displayName" -o tsv)

sqlAdmin=$(az sql server show --name $databaseServer -g $resourceGroupName --query "administratorLogin"  -o tsv)

# new random password
# https://learn.microsoft.com/en-us/sql/relational-databases/security/password-policy?view=sql-server-ver16
sqlPassword=$(sed "s/[^a-zA-Z0-9\!#\$%*()]//g" <<< $(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%*()-+' | fold -w 32 | head -n 1))

echo "connecting to: $databaseServerFqdn"
echo "opening: $databaseName"

# disable Azure AD only admin access
az sql server ad-only-auth disable -n $databaseServer -g $resourceGroupName

az sql server update -n $databaseServer -g $resourceGroupName -p $sqlPassword

cat <<SCRIPT_END > createSqlUser.sql
DECLARE @myObjectId varchar(100) = '$objectIdForCurrentUser'
DECLARE @sid binary(16) = CAST(CAST(@myObjectId as uniqueidentifier) as binary(16))

DECLARE @sql nvarchar(max) = N'CREATE user [$azureAdUsername] WITH TYPE = E, SID = 0x' + convert(varchar(1000), @sid, 2);

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'$azureAdUsername')
	EXEC sys.sp_executesql @sql;

SCRIPT_END

export SQLCMDPASSWORD=$sqlPassword
./sqlcmd -S "tcp:$databaseServerFqdn,1433" -U $sqlAdmin -i createSqlUser.sql

cat <<SCRIPT_END > updateSqlUserPerms.sql
DECLARE @myObjectId varchar(100) = '$objectIdForCurrentUser'
DECLARE @sid binary(16) = CAST(CAST(@myObjectId as uniqueidentifier) as binary(16))

DECLARE @sql nvarchar(max) = N'CREATE user [$azureAdUsername] WITH TYPE = E, SID = 0x' + convert(varchar(1000), @sid, 2);

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'$azureAdUsername')
	EXEC sys.sp_executesql @sql;

IF NOT EXISTS (SELECT * FROM sys.database_principals p JOIN sys.database_role_members db_owner_role ON db_owner_role.member_principal_id = p.principal_id JOIN sys.database_principals role_names ON role_names.principal_id = db_owner_role.role_principal_id AND role_names.[name] = 'db_owner' WHERE p.[name]=N'$azureAdUsername')
  ALTER ROLE db_owner ADD MEMBER [$azureAdUsername];

SCRIPT_END

./sqlcmd -S "tcp:$databaseServerFqdn,1433" -d $databaseName -U $sqlAdmin -i updateSqlUserPerms.sql

export SQLCMDPASSWORD=clear

# enable Azure AD only admin access
az sql server ad-only-auth enable -n $databaseServer -g $resourceGroupName

printf "${green}Finished successfully${clear}"
echo ""

exit 0