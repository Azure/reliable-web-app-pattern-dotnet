# Scalable Web App Pattern

This repository provides resources to help developers build a Scalable web app on Azure. A Scalable Web App is a set of services, code, and infrastructure deployed in Azure that applies practices from the Well-Architected Framework. This pattern is shared with three components to help you use Azure to build a web app that follows Microsoft's recommended guidance for achieving reliability, scalability, and security in the cloud.

3 components of the Scalable web app are:
* [A Guide](ScalableWebApp.md) that demonstrates the guidance and explains the context surrounding the decisions that were made to build this solution
* A starting point solution that demonstrates how these decisions were implemented as code
* A starting point deployment pipeline with bicep resources that demonstrate how the infrastructure decisions were implemented

# Deploy to Azure

The reference scenario in this sample is for Relecloud
Concerts, a fictional company that sells concert tickets. Their website, is an illustrative example of an eCommerce application. This reference application uses the Azure Dev CLI to set up Azure services and deploy the code. Deploying the code requires the creation of Azure services, configuration of permissions, and creating Azure AD App Registrations.
## Pre-requisites

1. [Install the Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).
    Run the following command to verify that you're running version
    2.38.0 or higher.

    ```ps1
    az version
    ```
    
    After the installation, run the following command to [sign in to Azure interactively](https://learn.microsoft.com/cli/azure/authenticate-azure-cli#sign-in-interactively).

    ```ps1
    az login
    ```
1. [Install the Azure Dev CLI](https://docs.microsoft.com/en-us/azure/developer/azure-developer-cli/get-started?tabs=bare-metal%2Cwindows&pivots=programming-language-csharp#configure-your-development-environment).
    Run the following command to verify that the Azure Dev CLI is installed.

    ```ps1
    azd version
    ```

1. [Install .NET 6 SDK](https://dotnet.microsoft.com/en-us/download/dotnet/6.0)
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
```ps1
$myEnvironmentName = "relecloudresources"
azd env new -e $myEnvironmentName
```

> bash users
> 
> ```bash
> myEnvironmentName = "relecloudresources"
> azd env new -e $myEnvironmentName
> ```

<br />

**Choose Prod or Non-prod environment**

The Relecloud team uses the same bicep templates to deploy
their production, and non-prod, environments. To do this
they set `azd` environment parameters that change the behavior
of the next steps.

> If you skip the next two optional steps, and change nothing,
> then the bicep templates will default to non-prod settings.

*OPTIONAL: 1*

Relecloud devs deploy the production environment by running the
following command to choose the SKUs they want in production.

```ps1
azd env set IS_PROD true
```

*OPTIONAL: 2*

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

**Provision the infrastructure**

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

**Create App Registrations**

Relecloud devs have automated the process of creating Azure
AD resources that support the authentication features of the
web app. They use the following command to create two new
App Registrations within Azure AD. The command is also
responsible for saving configuration data to Key Vault and
App Configuration so that the web app can read this data.

```ps1
./infra/createAppRegistrations.ps1 -g "$myEnvironmentName-rg"
```

> bash users
> 
> ```bash
> ./infra/createAppRegistrations.sh -g "$myEnvironmentName-rg"
> ```

**Deploy the code**

To finish the deployment process the Relecloud devs run the
folowing `azd` commands to build, package, and deploy the dotnet
code for the front-end and API web apps.

```ps1
 azd env set AZURE_RESOURCE_GROUP "$myEnvironmentName-rg"
```

```ps1
 azd deploy
```

> When finished the console will display the URI for the web
> app. You can use this URI to view the deployed solution in a
> browser.

![screenshot of Relecloud app home page](./assets/Guide/WebAppHomePage.png)

<br />

> You should use the `azd down --force --purge --no-prompt` command to tear down an
> environment when you have finished with these services. If
> you want to recreate this deployment you will also need to
> delete the two Azure AD app services that were created. You
> can find them in Azure AD by searching for their environment
> name. You will also need to purge the Key Vault and App
> Configuration Service instances that were deployed.

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

        ```ps1
        ./infra/getSecretsForLocalDev.ps1 -g "$myEnvironmentName-rg" -Web
        ```
        > bash users
        > 
        > ```bash
        > ./infra/getSecretsForLocalDev.sh -g "$myEnvironmentName-rg" --web
        > ```

    4. Copy the output into the `secrets.json` file for the **Relecloud.Web**
    project.

3. Setup the **Relecloud.Web.Api** project User Secrets
    1. Right-click on the **Relecloud.Web.Api** project
    2. From the context menu choose **Manage User Secrets**
    3. From a command prompt run the bash command

        ```ps1
        ./infra/getSecretsForLocalDev.ps1 -g "$myEnvironmentName-rg" -Api
        ```
        > bash users
        > 
        > ```bash
        > ./infra/getSecretsForLocalDev.sh -g "$myEnvironmentName-rg" --api
        > ```

    4. Copy the output into the `secrets.json` file for the 
    **Relecloud.Web.Api** project.

4. Right-click the **Relecloud** solution and pick **Set Startup Projects...**
5. Choose **Multiple startup projects**
6. Change the dropdowns for *Relecloud.Web* and *Relecloud.Web.Api* to the action of **Start**.
7. Click **Ok** to close the popup
8. Add your IP address to the SQL Database firewall as an allowed connection by using the following commands

    ```ps1
    $myIpAddress = (Invoke-WebRequest ipinfo.io/ip)
    ```
    > bash users
    > 
    > ```bash
    > myIpAddress=$(wget -q -O - ipinfo.io/ip)
    > ```

    ```ps1
    $mySqlServer = (az resource list -g "$myEnvironmentName-rg" --query "[?type=='Microsoft.Sql/servers'].name" -o tsv)
    ```
    > bash users
    > 
    > ```bash
    > mySqlServer=$(az resource list -g "$myEnvironmentName-rg" --query "[?type=='Microsoft.Sql/servers'].name" -o tsv)
    > ```

    ```ps1
    az sql server firewall-rule create -g "$myEnvironmentName-rg" -s $mySqlServer -n "devbox_$(date +"%Y-%m-%d_%I-%M-%S")" --start-ip-address $myIpAddress --end-ip-address $myIpAddress
    ```
    > bash users
    > 
    > ```bash
    > az sql server firewall-rule create -g "$myEnvironmentName-rg" -s $mySqlServer -n "devbox_$(date +"%Y-%m-%d_%I-%M-%S")" --start-ip-address $myIpAddress --end-ip-address $myIpAddress
    > ```

9. When connecting to Azure SQL database you'll connect with your Azure AD account.
Run the following command to give your Azure AD account permission to access the database.

    ```ps1
    ./infra/makeSqlUserAccount.ps1 -g "$myEnvironmentName-rg"
    ```
    > bash users
    > 
    > ```bash
    > ./infra/makeSqlUserAccount.sh -g "$myEnvironmentName-rg"
    > ```

10. Press F5 to start debugging the website


