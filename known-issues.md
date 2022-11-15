# Known issues
This content is still in the early stages, so you may run into some issues. Here are the significant known issues that exist in the current version.

1. Data consistency for multi-regional deployments
1. Challenges that surface when trying the code

# Data consistency for multi-regional deployments

This sample includes a feature to deploy the code to two Azure regions. The feature is intended to support the high availability scenario by deploying resources that support an active/passive deployment. The sample currently supports the ability to fail-over web-traffic and process requests from a second region but does not support data synchronization between two regions. 

This can result in users losing trust in the system when they observe that the system is online but their data is missing. In the next sections we examine the stateful parts of the application to explain how data consistency applies to each component.

### Azure SQL Database

Azure SQL Database is used to store information about concerts, customer ids, and the tickets that they've purchased. This service stores this data and the relationships between this data to help customers see the right details when they login.

Without synchronizing this data customers will not be able to see the tickets that they purchased. And, when the code runs in two regions it will randomly seed the data in different order, so the concert details will not appear the same in both regions.

To address this concern we recommend two Azure SQL Features:

* [Active geo-replication](https://learn.microsoft.com/en-us/azure/azure-sql/database/active-geo-replication-overview) to synchronize data between the two regions
* [Auto-failover groups](https://learn.microsoft.com/en-us/azure/azure-sql/database/auto-failover-group-sql-db) to handle the failover of the system from one region to another

### Azure Storage

Azure Storage is used to store the tickets that are rendered during the checkout flow. These tickets are images that are durably stored with zone-redundancy to improve SLAs regarding the risk of data loss. The next factor of concern is our ability to read and write to this data source on-demand.

Using geo-redundant storage would increase our ability to read the data but not our ability to write to storage. So in this sample we use two separate storage accounts which have their own availability for write operations to improve our composite availability. However, maintaining two Azure Storage accounts is subject to the same concerns that apply to our Azure SQL database.

To learn more about what you can do to address this concern we recommend the following article:
* [Use geo-redundancy to design highly available applications](https://learn.microsoft.com/en-us/azure/storage/common/geo-redundant-design?toc=%2Fazure%2Fstorage%2Fblobs%2Ftoc.json)


### External configuration with Key Vault and App Configuration Service

Azure App Configuration Service and Key Vault are used to store the configuration and secrets. These details enable our app to create service to service connections and control the behavior of our app. In this active/passive scenario we do not include additional complexity for the secrets from two regions to be kept in sync or for the web apps to automatically detect changes to these configurations.

One recommended approach to synchronize data between the two regions is to use devOps workflows to automate the deployment of configuration.

Another approach is to use Azure features to schedule a data synchronization between the two resources deployed to two regions.

Learn more by reading about:

* [Synchronization between Azure App Configuration Stores](https://learn.microsoft.com/en-us/azure/azure-app-configuration/concept-disaster-recovery?tabs=core2x#synchronization-between-configuration-stores)


### Azure Cache for Redis

The data stored in Azure Cache for Redis can be replicated across regions. This sample chooses not to implement this feature as the additional features are not appropriate for the Relecloud scenario.

To reach this decision you must examine the data that you store in Azure Cache for Redis to understand whether additional complexity adds value to your scenario.

* Cached Concert details - (TODO)
* MSAL tokens - (TODO)
* Cart info - Each user of the Relecloud system may have tickets in their cart at the time of a failover event. However this data is typically short lived and the cost of keeping two data regions in sync increases as the data between them becomes more frequently synced.

If you choose to implement regional data consitency for your scenario you should review these documents for options.

* [Configure active geo-replication for Enterprise Azure Cache for Redis instances](https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/cache-how-to-active-geo-replication)
* [High availability and disaster recovery for Azure Cache for Redis](https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/cache-high-availability#importexport)


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
