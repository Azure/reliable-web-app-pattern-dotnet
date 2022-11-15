# Known issues
This pattern is still in the early stages, so you may run into some issues. Here are the significant known issues that exist in the current version.

1. Data consistency for multi-regional deployments
1. Challenges that surface when trying the code


## 1. Data consistency for multi-regional deployments

[TODO]


## 2. Challenges that surface when trying the code

* Cannot execute shellscript `/bin/bash^M: bad interpreter`
* Login failed for user '&lt;token-identified principal&gt;' SQL Server, Error 18456


## Cannot execute shellscript `/bin/bash^M: bad interpreter`
This error happens when Windows users checked out code from a Windows environment
and try to execute the code from Windows Subsystem for Linux (WSL). The issue is
caused by Git tools that automatically convert `LF` characters based on the local
environment.

Run the following commands to change the windows line endings to linux line endings:

```bash
sed "s/$(printf '\r')\$//" -i ./infra/appConfigSvcPurge.sh
sed "s/$(printf '\r')\$//" -i ./infra/addLocalIPToSqlFirewall.sh
sed "s/$(printf '\r')\$//" -i ./infra/createAppRegistrations.sh
sed "s/$(printf '\r')\$//" -i ./infra/getSecretsForLocalDev.sh
sed "s/$(printf '\r')\$//" -i ./infra/makeSqlUserAccount.sh
sed "s/$(printf '\r')\$//" -i ./infra/validateDeployment.sh
```


## Login failed for user '&lt;token-identified principal&gt;' SQL Server, Error 18456

This error happens when attempting to connect to the Azure SQL Server with as
an Active Directory user, or service principal, that has not been added as a SQL
user.

To fix this issue you need to connect to the SQL Database using the SQL Admin account
and to add the Azure AD user.

Documentation can help with this task: [Create contained users mapped to Azure AD identities](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-configure?tabs=azure-powershell&view=azuresql#create-contained-users-mapped-to-azure-ad-identities)

This error can also happen if you still need to run the `makeSqlUserAccount.ps1` script.