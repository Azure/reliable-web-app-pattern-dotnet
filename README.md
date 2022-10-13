# Scalable Web App Pattern

This repository provides resources to help developers build a Scalable web app on Azure. A Scalable Web App is a set of services, code, and infrastructure deployed in Azure that applies practices from the Well-Architected Framework. This pattern is shared with three components to help you use Azure to build a web app that follows Microsoft's recommended guidance for achieving reliability, scalability, and security in the cloud.

3 components of the Scalable web app are:
* [A Guide](ScalableWebApp.md) that demonstrates the guidance and explains the context surrounding the decisions that were made to build this solution
* A starting point solution that demonstrates how these decisions were implemented as code
* A starting point deployment pipeline with bicep resources that demonstrate how the infrastructure decisions were implemented

To Get Started on Scalable Web App Patterns, [Watch the Introduction Video (8 mins)](https://microsoftapc-my.sharepoint.com/:v:/g/personal/nanil_microsoft_com/EaFYz80v2W1CoGKwFxbvuIEBLO6xenwwtv03apn3yv6mMg):

[![screenshot azd env new](./assets/Guide/Intro-video.png)](https://microsoftapc-my.sharepoint.com/:v:/g/personal/nanil_microsoft_com/EaFYz80v2W1CoGKwFxbvuIEBLO6xenwwtv03apn3yv6mMg)

# Deploy to Azure

The reference scenario in this sample is for Relecloud
Concerts, a fictional company that sells concert tickets. Their website, is an illustrative example of an eCommerce application. This reference application uses the Azure Dev CLI to set up Azure services and deploy the code. Deploying the code requires the creation of Azure services, configuration of permissions, 
and creating Azure AD App Registrations.

### Pricing: What does it cost to run this on Azure?

The Relecloud team uses lower-price SKUs for non-prod workloads to manage costs while building testing environments. For production, the app is designed to run on two different Azure Regions for high availability. 

| Environment | SLA | Estimated Cost(per month) | Comments |
| ------------- | ------------- | ------------- | ------------- |
| ✅**Dev/Test** | 99.56% | $244 per environment | Lower price SKUs used.  |
| ✅**Production** | 99.98% | $2,039.60 | Premium SKUs used for **High Availability**.   |

> Cost is estimated based on the **East US** and **West US 3** Azure Regions. For detailed cost analysis, refer to the cost section in the [accompanying guide](./ScalableWebApp.md#cost).

## Pre-requisites

1. [Install the Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli).
    Run the following command to verify that you're running version
    2.38.0 or higher.

    ```ps1
    az version
    ```
    
    After the installation, run the following command to [sign in to Azure interactively](https://learn.microsoft.com/cli/azure/authenticate-azure-cli#sign-in-interactively).

    ```ps1
    az login
    ```
1. [Install the Azure Dev CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd).
    Run the following command to verify that the Azure Dev CLI is installed.

    ```ps1
    azd version
    ```

1. [Install .NET 6 SDK](https://dotnet.microsoft.com/download/dotnet/6.0)
    Run the following command to verify that the .NET SDK 6.0 is installed.
    ```ps1
    dotnet --version
    ```
## Deploy the code

Relecloud's developers use the `azd` command line experience to deploy the code. This means their local workflow is the same
experience that runs from the GitHub action. You can use these
steps to follow their experience by running the commands from the folder where this guide is stored after cloning this repo.

Use this command to get started with deployment by creating an
`azd` environment on your workstation.

<!-- TODO - Expecting this to change for new version https://github.com/Azure/azure-dev/issues/502 -->



<table>
<tr>
<td>PowerShell</td>
<td>

```ps1
$myEnvironmentName="relecloudresources"
azd env new -e $myEnvironmentName
```

</td>
</tr>
<tr>
<td>Bash</td>
<td>

```bash
myEnvironmentName="relecloudresources"
azd env new -e $myEnvironmentName
```

</td>
</tr>
</table>

When prompted, select the preferred Azure Subscription and the Location:

![screenshot azd env new](./assets/Guide/Azd-Env-New.png)

### (Optional Steps) Choose Prod or Non-prod environment

The Relecloud team uses the same bicep templates to deploy
their production, and non-prod, environments. To do this
they set `azd` environment parameters that change the behavior
of the next steps.

> If you skip the next two optional steps, and change nothing,
> then the bicep templates will default to non-prod settings.

*Step: 1*

Relecloud devs deploy the production environment by running the
following command to choose the SKUs they want in production.

```ps1
azd env set IS_PROD true
```

*Step: 2*

Relecloud devs also use the following command to choose a second
Azure location because the production environment is
multiregional.

```ps1
azd env set SECONDARY_AZURE_LOCATION westus3
```

> You can find a list of available Azure regions by running
> the following Azure CLI command.
> 
> ```ps1
> az account list-locations --query "[].name" -o tsv
> ```

<br />

### Provision the infrastructure

Relecloud uses the following command to deploy the Azure
services defined in the bicep files by running the provision
command.

> This step will take several minutes based on the region
> and deployment options you selected.

```ps1
azd provision
```

> When the command finishes you have deployed Azure App
> Service, SQL Database, and supporting services to your
> subscription. If you log into the the
> [Azure Portal](http://portal.azure.com) you can find them
> in the resource group named `$myEnvironmentName-rg`.

<br />

#### Create App Registrations

Relecloud devs have automated the process of creating Azure
AD resources that support the authentication features of the
web app. They use the following command to create two new
App Registrations within Azure AD. The command is also
responsible for saving configuration data to Key Vault and
App Configuration so that the web app can read this data.

<table>
<tr>
<td>PowerShell</td>
<td>

```ps1
.\infra\createAppRegistrations.ps1 -g "$myEnvironmentName-rg"
```

</td>
</tr>
<tr>
<td>Bash</td>
<td>

```bash
bash ./infra/createAppRegistrations.sh -g "$myEnvironmentName-rg"
```

</td>
</tr>
</table>

#### Deploy the code

To finish the deployment process the Relecloud devs run the
folowing `azd` commands to build, package, and deploy the dotnet
code for the front-end and API web apps.

```ps1
 azd env set AZURE_RESOURCE_GROUP "$myEnvironmentName-rg"
```

```ps1
 azd deploy
```

When finished the console will display the URI for the web app. You can use this URI to view the deployed solution in a browser.

![screenshot of Relecloud app home page](./assets/Guide/WebAppHomePage.png)

<br />

> If you face any issues with the deployment, see the [Known issues section](./README.md#known_issues) below for possible workarounds. There could be interim issues while deploying to Azure, and repeating the steps after a few minutes should fix most of them. Azure deployments are incremental by default, and only failed actions will be retired.

### Clean up Azure Resources

To tear down an enviroment, and clean up the Azure resource group, use the folloing command:

```ps1
azd down --force --purge --no-prompt
```

 If you want to recreate this deployment you will also need to delete the two Azure AD app registrations that were created. You can find them in Azure AD by searching for their environment name. 
 
 **Delete App Registrations** 

 ![screenshot of Azure AD App Registrations](./assets/Guide/AD-AppRegistrations.png)
 
 You will also need to purge the App Configuration Service instance that was deployed.

 **Purge App Configurations**

 ![screenshot of Purging App Configurations](./assets/Guide/AppConfig-Purge.png)

## Local Development

Relecloud developers use Visual Studio to develop locally and they co-share
an Azure SQL database for local dev. The team chooses this workflow to
help them practice early integration of changes as modifying the
database and other shared resources can impact multiple workstreams.

To connect to the shared database the dev team uses connection strings
from Key Vault and App Configuration Service. Devs use the following
script to retrieve data and store it as
[User Secrets](https://docs.microsoft.com/en-us/aspnet/core/security/app-secrets?view=aspnetcore-6.0&tabs=windows)
on their workstation.

Using the `secrets.json` file helps the team keep their credentials
secure. The file is stored outside of the source control directory so
the data is never accidentally checked-in. And the devs don't share
credentials over email or other ways that could compromise their
security.

Managing secrets from Key Vault and App Configuration ensures that only
authorized team members can access the data and also centralizes the
administration of these secrets so they can be easily changed.

New team members should setup their environment by following these steps.

1. Open the Visual Studio solution `./src/Relecloud.sln`
2. Setup the **Relecloud.Web** project User Secrets
    1. Right-click on the **Relecloud.Web** project
    2. From the context menu choose **Manage User Secrets**
    3. From a command prompt run the bash command

        <table>
        <tr>
        <td>PowerShell</td>
        <td>

        ```ps1
        .\infra\getSecretsForLocalDev.ps1 -g "$myEnvironmentName-rg" -Web
        ```

        </td>
        </tr>
        <tr>
        <td>Bash</td>
        <td>
                
        ```bash
        bash ./infra/getSecretsForLocalDev.sh -g "$myEnvironmentName-rg" --web
        ```

        </td>
        </tr>
        </table>

    4. Copy the output into the `secrets.json` file for the **Relecloud.Web**
    project.

3. Setup the **Relecloud.Web.Api** project User Secrets
    1. Right-click on the **Relecloud.Web.Api** project
    2. From the context menu choose **Manage User Secrets**
    3. From a command prompt run the bash command

        <table>
        <tr>
        <td>PowerShell</td>
        <td>

        ```ps1
        .\infra\getSecretsForLocalDev.ps1 -g "$myEnvironmentName-rg" -Api
        ```

        </td>
        </tr>
        <tr>
        <td>Bash</td>
        <td>
                
        ```bash
        bash ./infra/getSecretsForLocalDev.sh -g "$myEnvironmentName-rg" --api
        ```

        </td>
        </tr>
        </table>

    4. Copy the output into the `secrets.json` file for the 
    **Relecloud.Web.Api** project.

4. Right-click the **Relecloud** solution and pick **Set Startup Projects...**
5. Choose **Multiple startup projects**
6. Change the dropdowns for *Relecloud.Web* and *Relecloud.Web.Api* to the action of **Start**.
7. Click **Ok** to close the popup
8. Add your IP address to the SQL Database firewall as an allowed connection by using the following script

    <table>
    <tr>
    <td>PowerShell</td>
    <td>

    ```ps1
    .\infra\addLocalIPToSqlFirewall.ps1 -g "$myEnvironmentName-rg"
    ```

    </td>
    </tr>
    <tr>
    <td>Bash</td>
    <td>
            
    ```bash
    bash ./infra/addLocalIPToSqlFirewall.sh -g "$myEnvironmentName-rg"
    ```

    </td>
    </tr>
    </table>

9. When connecting to Azure SQL database you'll connect with your Azure AD account.
Run the following command to give your Azure AD account permission to access the database.

    <table>
    <tr>
    <td>PowerShell</td>
    <td>

    ```ps1
    .\infra\makeSqlUserAccount.ps1 -g "$myEnvironmentName-rg"
    ```

    </td>
    </tr>
    <tr>
    <td>Bash</td>
    <td>
            
    ```bash
    bash ./infra/makeSqlUserAccount.sh -g "$myEnvironmentName-rg"
    ```

    </td>
    </tr>
    </table>

10. Grant your account access to Azure App Configuration Service

    <table>
    <tr>
    <td>PowerShell</td>
    <td>

    ```ps1
    $appConfigDataReaderRole='516239f1-63e1-4d78-a4de-a74fb236a071'
    $currentUserObjectId=(az ad signed-in-user show --query "id" -o tsv)
    $scopeId=(az group show -n "$myEnvironmentName-rg" --query "id" -o tsv)
    az role assignment create --role $appConfigDataReaderRole --assignee $currentUserObjectId --scope $scopeId
    ```

    </td>
    </tr>
    <tr>
    <td>Bash</td>
    <td>
            
    ```bash
    appConfigDataReaderRole='516239f1-63e1-4d78-a4de-a74fb236a071'
    currentUserObjectId=$(az ad signed-in-user show --query "id" -o tsv)
    scopeId=$(az group show -n "$myEnvironmentName-rg" --query "id" -o tsv)
    az role assignment create --role $appConfigDataReaderRole --assignee $currentUserObjectId --scope $scopeId
    ```

    </td>
    </tr>
    </table>

11. Press F5 to start debugging the website

> These steps grant access to SQL server in the primary resource group.
> You can use the same commands if you want to test with the secondary resource
> group by changing the ResourceGroup parameter "-g" to "$myEnvironmentName-secondary-rg"

# Known issues
If you encounter issues with your deployment you can try running the following command
to analyze the issue and receive a recommendation.

<table>
<tr>
<td>PowerShell</td>
<td>

```ps1
.\infra\validateDeployment.ps1 -g "$myEnvironmentName-rg"
```

</td>
</tr>
<tr>
<td>Bash</td>
<td>

```bash
./infra/validateDeployment.sh -g "$myEnvironmentName-rg"
```

</td>
</tr>
</table>


You may also find the following topics helpful.

## Cannot execute shellscript `/bin/bash^M: bad interpreter`
This error happens when Windows users checked out code from a Windows environment
and try to execute the code from Windows Subsystem for Linux (WSL). The issue is
caused by Git tools that automatically convert `LF` characters based on the local
environment.

Run the following commands to change the windows line endings to linux line endings:

```bash
sed "s/$(printf '\r')\$//" -i ./infra/createAppRegistrations.sh
sed "s/$(printf '\r')\$//" -i ./infra/addLocalIPToSqlFirewall.sh
sed "s/$(printf '\r')\$//" -i ./infra/getSecretsForLocalDev.sh
sed "s/$(printf '\r')\$//" -i ./infra/makeSqlUserAccount.sh
```

## App doesn't start: 500.30 ASP.NET Core app failed to start

This issue is due to missing configuration on your App Service you should **re-run** the `azd provision` command. The Azure Dev CLI performs incremental deployments that will overlay the correct settings on the existing App Service.

> This is a known issue and we are tracking it [here](https://github.com/Azure/scalable-web-app-pattern-dotnet/issues/87).

## Login failed for user '&lt;token-identified principal&gt;' SQL Server, Error 18456

This error happens when attempting to connect to the Azure SQL Server with as
an Active Directory user, or service principal, that has not been added as a SQL
user.

To fix this issue you need to connect to the SQL Database using the SQL Admin account
and to add the Azure AD user.

Documentation can help with this task: [Create contained users mapped to Azure AD identities](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-configure?tabs=azure-powershell&view=azuresql#create-contained-users-mapped-to-azure-ad-identities)

This error can also happen if you still need to run the `makeSqlUserAccount.ps1` script.
