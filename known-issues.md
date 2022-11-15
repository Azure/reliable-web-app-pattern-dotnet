# Known issues
This pattern is still in the early stages, so you may run into some issues. Here are the significant known issues that exist in the current version.

1. Data consistency for multi-regional deployments
1. Challenges that surface when trying the code

<br />

# Data consistency for multi-regional deployments
This sample includes a feature to deploy the code to two Azure regions. The feature is intended to support the high availability scenario by providing an active/passive scenario. The sample currently supports the ability to fail-over web-traffic and process requests in the new region but does not support data synchronization between two regions. This can result in users losing trust in the system when they observe that the system is online but their data is missing. In the next sections we examine the stateful parts of the application to explain how data consistency applies to each component.

### Azure SQL Database

(TODO)

### External configuration with Key Vault and App Configuration Service

(TODO)

### Azure Cache for Redis

The data stored in Azure Cache for Redis can be replicated across regions. This sample chooses not to implement this feature as the additional features are not appropriate for the Relecloud scenario.

To reach this decision you must examine the data that you store in Azure Cache for Redis to understand whether additional complexity adds value to your scenario.

* Cached Concert details - (TODO)
* MSAL tokens - (TODO)
* Cart info - Each user of the Relecloud system may have tickets in their cart at the time of a failover event. However this data is typically short lived and the cost of keeping two data regions in sync increases as the data between them becomes more frequently synced.

If you choose to implement regional data consitency for your scenario you should review these documents for options.

* [Configure active geo-replication for Enterprise Azure Cache for Redis instances](https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/cache-how-to-active-geo-replication)
* [High availability and disaster recovery for Azure Cache for Redis](https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/cache-high-availability#importexport)

<br />

# Challenges that surface when trying the code

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