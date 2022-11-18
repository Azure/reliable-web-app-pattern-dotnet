# Known issues
This content is still in the early stages, so you may run into some issues. Here are the significant known issues that exist in the current version.

## Shared Access Signatures for Azure Storage

This sample uses a connection string with a secret to connect directly to Azure storage. This serves to demonstrate
how to apply the [Valet Key Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/valet-key) but is not the best fit for this scenario. In Relecloud's scenario, the [shared
access signature (SAS)](https://learn.microsoft.com/en-us/rest/api/storageservices/delegate-access-with-shared-access-signature) approach provides limited time access to the tickets that were purchased. In a production scenario
we do not recommend this approach as customers would need to run a schedule job to recycle the shared access signatures
in order to rotate the secret key associated with the account. Further, the SAS token approach limits the lifetime
of access to 30-days and a new SAS uri would need to be generated after the current one expires.

Open issue:
* [Setup network isolation for Azure Storage](https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/12)

## Data consistency for multi-regional deployments

This sample includes a feature to deploy to two Azure regions. The feature is intended to support the high availability scenario by deploying resources in an active/passive configuration. The sample currently supports the ability to fail-over web-traffic so requests can be handled from a second region. However it does not support data synchronization between two regions. 

This can result in users losing trust in the system when they observe that the system is online but their data is missing. In the next sections we examine the stateful parts of the application to explain how data consistency applies to each component.

Open issues:
* [Implement multiregional Azure SQL](https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/44)
* [Implement multiregional Storage](https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/122)
* [Secondary Key Vault not populated by createAppRegistrations.sh](https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/135)

### Azure SQL Database

Azure SQL Database is used to store information about concerts, customers, and the tickets that they've purchased. This service stores this data and the relationships between this data to help customers shop for concerts and see their tickets when they login.

Without synchronizing this data, customers will not be able to see the tickets that they purchased. And, when the code runs in two regions it will randomly seed the data in a different order, so the concert details will not appear the same after a failover.

To address this concern we recommend two Azure SQL Features:

* [Active geo-replication](https://learn.microsoft.com/en-us/azure/azure-sql/database/active-geo-replication-overview) to synchronize data between the two regions
* [Auto-failover groups](https://learn.microsoft.com/en-us/azure/azure-sql/database/auto-failover-group-sql-db) to handle the failover of the system from one region to another

### Azure Storage

Azure Storage is used to store the tickets that are created during the checkout flow. These tickets are images that are durably stored with zone-redundancy to improve SLAs related for data retention. The next factor of concern is our ability to read and write to this data source.

Using geo-redundant storage would increase our ability to read the data but not our ability to write to storage. So in this sample we use two separate storage accounts which have their own availability for write operations to improve our composite availability. However, maintaining two Azure Storage accounts is subject to the same concerns that apply to our Azure SQL database.

To learn more about what you can do to address this concern we recommend the following article:
* [Use geo-redundancy to design highly available applications](https://learn.microsoft.com/en-us/azure/storage/common/geo-redundant-design?toc=%2Fazure%2Fstorage%2Fblobs%2Ftoc.json)


### External configuration with Key Vault and App Configuration Service

Azure App Configuration Service and Key Vault are used to store the configuration and secrets. These details enable our app to create service-to-service connections and control the behavior of our app. In this active/passive scenario we do not include additional complexity to synchronize this data or for the web apps to automatically detect changes to these configurations.

One recommended approach to synchronize data between the two regions is to use devOps workflows to automate the deployment of configuration. This ensures both regions are kept in sync and also provides the righ timing to recycle the web apps and ensure new settings are loaded.

Another approach is to use Azure features to schedule a data synchronization between the two resources deployed to two regions.

Learn more by reading about:

* [Synchronization between Azure App Configuration Stores](https://learn.microsoft.com/en-us/azure/azure-app-configuration/concept-disaster-recovery?tabs=core2x#synchronization-between-configuration-stores)


### Azure Cache for Redis

The data stored in Azure Cache for Redis can be replicated across regions. This sample chooses not to implement this feature as the features are not appropriate for the Relecloud scenario.

To reach this decision you must examine the data that you store in Azure Cache for Redis to understand whether additional complexity adds value to your scenario.

* Cached Concert details - These details offload pressure from the SQL server by periodically caching results from the SQL database for our most frequently executed query. We expect the cache to be repopulated in the new region on demand during a fail-over event.
* MSAL tokens - These tokens are issued by Azure AD so that the web app can make tokens to the web API app on behalf of the currently authenticated user. During a failover we do not expect users will have to reauthenticate because they have already completed Single Sign On and we expect the *Microsoft.Identity.Web* library will retrieve new MSAL tokens as needed to authenticate to the web API.
* Cart info - Each user of the Relecloud system may have tickets in their cart at the time of a failover event. However this data is typically short lived and the cost of keeping two data regions in sync increases as the data between them becomes more frequently synced. For simplicity, we accept that customers will lose their cart information and must re-add tickets to their cart if a fail-over happens.

If you choose to implement regional data consitency for your scenario you should review these documents for options.

* [Configure active geo-replication for Enterprise Azure Cache for Redis instances](https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/cache-how-to-active-geo-replication)
* [High availability and disaster recovery for Azure Cache for Redis](https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/cache-high-availability#importexport)

## Error: no project exists; to create a new project, run 'azd init'
When using the `azd provision` command it will check your current working directory for an `azure.yaml` file.

This error happens if you are running `azd` from an uninitialized folder. You may need to `cd` into the directory you cloned to run this command.

## The deployment 'relecloudresources' already exists in location
This may happen if you use `azd` to choose the *eastus* region and then decide to choose another Azure region.

When the `azd provision` command runs it creates a deployment resource in your subscription. You must delete this deployment before you can change the Azure region.

Please see the [teardown instructions](deploy-solution.md#clean-up-azure-resources) to address this issue.

*There are no open items open for this issue.*

## ContainerOperationFailure
The Relecloud sample deploys an Azure Storage account with a container. In this scenario the deployment
of the Azure Storage container failed because the Azure Storage Account did not exist.

```json
{
    "status": "Failed",
    "error": {
        "code": "ContainerOperationFailure",
        "message": "The specified resource does not exist.\nRequestId:aaaaaaaa-4444-0000-6666-ffffffffffff\nTime:2022-11-15T16:41:16.8992424Z"
    }
}
```

The recommended workaround is to retry the `azd provision` command if this happens during your deployment.

Open issue:
* [Azure Storage container operation failure](https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/154)

## DeploymentScriptBootstrapScriptExecutionFailed
The Relecloud sample uses deployment scripts to run cli or PowerShell commands to configure Azure resources that
require multiple steps to provision. As an example, the Azure SQL database is created to allow public connection
and then a script is used create the SQL user that represents the managed identity. After the SQL user is created
the script will change properties of the Azure SQL instance to prevent public access.

These scripts run in could fail during your deployment. If this happens the error look like the following:

```json
{
    "status": "failed",
    "error": {
        "code": "DeploymentScriptBootstrapScriptExecutionFailed",
        "message": "A service error occurred, the container group resource failed to start script execution. Correlation Id: bbbbbbbb-6666-4444-8888-555555555555. Please try again later, if the issue persists contact technical support for further investigation."
    }
}
```

The recommended workaround is to retry the `azd provision` command if this happens during your deployment.

Open issue:
* [Deployment Script Error](https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/89)

## Service request failed. Status: 403 (Forbidden) when running locally

When running the code from Visual Studio you may encounter an error as the app is starting.
![#image of hitting the exception in Visual Studio](https://user-images.githubusercontent.com/11169376/196296023-8fa320a8-c847-4f19-9c53-ce695142e6b6.png)

The steps for running locally include giving yourself the App Configuration Data Reader role
so that your account can read data from the App Configuration Service. Based on documentation this
role assignment can take up to 15-minutes to be fully applied. In team scenarios we recommend working around
this limitation by assigning the App Configuration Data Reader role to an Azure AD security group and
having dev team members joining the Security Group as part of joining a dev team.

Open issues:
* [App Config Svc permission takes time to propagate](https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/138)
* [Getting Auth errors when trying to debug locally in Visual Studio](https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/98)

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

*There are no open items open for this issue.*
