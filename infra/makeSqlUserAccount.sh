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
  echo 'FATAL ERROR: Missing required parameter --resource-group' 1>&2
  exit 6
fi

if ! [ -x "$(command -v ./sqlcmd)" ]; then
    echo 'installing sqlcmd'
    
    wget https://github.com/microsoft/go-sqlcmd/releases/download/v0.9.1/sqlcmd-v0.9.1-linux-x64.tar.bz2
    tar x -f sqlcmd-v0.9.1-linux-x64.tar.bz2
    
else
    echo 'found sqlcmd'
fi

azureAdUsername=$(az ad signed-in-user show --query userPrincipalName -o tsv)
objectIdForCurrentUser=$(az ad signed-in-user show --query id -o tsv)

keyVaultName=$(az resource list -g $resourceGroupName --query "[?type=='Microsoft.KeyVault/vaults' && name.starts_with(@, 'admin')].name" -o tsv)

databaseServer=$(az resource list -g $resourceGroupName --query "[?type=='Microsoft.Sql/servers'].name" -o tsv)
databaseServerFqdn=$(az sql server show -n $databaseServer -g $resourceGroupName --query fullyQualifiedDomainName -o tsv)
databaseName=$(az resource list -g $resourceGroupName --query "[?type=='Microsoft.Sql/servers/databases' && name.ends_with(@, 'database')].tags.displayName" -o tsv)
sqlAdmin=$(az keyvault secret show --vault-name $keyVaultName -n sqlAdministratorLogin --query value -o tsv)
sqlPassword=$(az keyvault secret show --vault-name $keyVaultName -n sqlAdministratorPassword --query value -o tsv)

echo "connecting to: $databaseServerFqdn"
echo "opening: $databaseName"

# disable Azure AD only admin access
az sql server ad-only-auth disable -n $databaseServer -g $resourceGroupName

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