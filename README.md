# Reliable web app pattern for .NET

> :mega: **Got feedback?** Fill out [this survey](https://aka.ms/eap/rwa/dotnet/survey) to help us shape the future of Enterprise App Patterns and understand whether we're focusing on the business goals and features important to you. [Microsoft Privacy Statement](https://go.microsoft.com/fwlink/?LinkId=521839)

The reference implementation provides a production-grade web application that uses best practices from our guidance and gives developers concrete examples to build their own Reliable Web Application in Azure. It simulates the journey from an on-premises ASP.NET application to a migration to Azure. It shows you what changes to make to maximize the benefits of the cloud in the initial cloud adoption phase. Here's an outline of the contents in this readme:

- [Azure Architecture Center guidance](#azure-architecture-center-guidance)
- [6 videos on the reliable web app pattern for .NET](#videos)
- [Architecture](#architecture)
- [Workflow](#workflow)
- [Steps to deploy the reference implementation](#steps-to-deploy-the-reference-implementation)
- [Additional links](#additional-links)
- [Data Collection](#data-collection)

## Azure Architecture Center guidance

This project has a [companion article in the Azure Architecture Center](https://aka.ms/eap/rwa/dotnet/doc) that describes design patterns and best practices for migrating to the cloud. We suggest you read it as it will give important context to the considerations applied in this implementation.

## Videos

This project has a six-part video series that details the reliable web app pattern for .NET web app. For more information, see [Reliable web app pattern videos (YouTube)](https://aka.ms/eap/rwa/dotnet/videos).

## Architecture

![architecture diagram](./assets/icons/reliable-web-app-dotnet.png)

## Workflow

- Azure Front Door routes traffic based on availability of the primary region. When the primary region is unavailable it will route traffic to the secondary region.
- When Front Door passes the request to the Web App, it will pass-through the Azure Web Application Firewall. The Azure Web Application Firewall will evaluate the request and protect the web app against common security attacks.
- Once the traffic reaches the web front-end users will be shown the home page. They can view these pages without authenticating.
- Navigating to the Concerts on the web app will send a request to the web front-end that tells it to ask the web api app for details about upcoming concerts.
- Details about the upcoming concerts will be retrieved from the Azure SQL Database by the web api app with a SQL query. The results will be formatted as a JSON response and returned to the web front-end.
- When the web front-end receives results from the API it will use razor template engine to render the HTML page shown to the user that asked for a list of concerts.
- Once a user adds a concert ticket to their shopping cart the front-end web app will start interacting with Azure Cache for Redis. Asking the web app to put a concert ticket into the cart tells the web app to save information about that pending purchase as JSON data in Redis as part of a session object for the current user. Saving the session to an external datastore enables the web app to load balance traffic more evenly and to handle horizontal scaling events without losing the customer's intent to buy a ticket. No inventory management is included in this sample so there are no quantities deducted, or placed on reserve, in the backend of the system.
- As the user checks out the front-end web app will ask the user to authenticate with Azure AD. This scenario is for a call center that places orders on-behalf of customers so the accounts in-use are managed by Relecloud and are not self-managed.
- After authenticating to Azure AD the front-end web app will receive a token from Azure AD that represents the current user. This token is saved as a cookie in the user's browser and is not persisted by the front-end web app.
- As the user proceeds with checkout the web app will collect payment data. Payment data is not sent anywhere for this sample.
- When the payment data is submitted for approval the ticket will be purchased. Logic to handle this is located in the web api project so the web app makes a call to the web api project.
- Prior to calling the API, the front-end web app asks the MSAL library for a token it can use to call the web api app as an authenticated user.
- When the MSAL library, in the front-end web app,  has a token it will cache it in Azure Cache for Redis. If it does not have a token it will request one from Azure AD and then save it in Azure Cache for Redis.
- Once the ticket purchase request is sent to the web api app the API will render the ticket image and save it to Azure storage.
- After the ticket purchase is completed successfully the user will be directed to their tickets page where they can see a list of the tickets they have purchased. These tickets will be immediately available because rendering the ticket was part of the purchase request.
  - As information flows between services the Azure network handles traffic routing across private endpoints by using Azure Private DNS to lookup the correct IP addresses. This enables the system to block public network traffic and use a single v-net to manage traffic between these systems. This v-net can be connected to others as-needed to allow the app to call other systems in your digital estate or to allow other systems to call the web API so they can access details about ticket purchases.
  - As the front-end, and web api, apps process requests they are sending data to Application Insights so that you can monitor information about processing web requests
  - When the web app is started for the first time it will load configuration data from App Config Service and Azure Key Vault. This information is saved in the web apps memory and is not accessed afterwards.

## Steps to deploy the reference implementation

The following detailed deployment steps assume you are using a Dev Container inside Visual Studio Code.

### 1. Clone the repo

Clone the repository from GitHub:

```shell
git clone https://github.com/Azure/modern-web-app-pattern-dotnet.git
cd modern-web-app-pattern-dotnet
```

### 2. Open Dev Container in Visual Studio Code (optional)

If required, ensure Docker Desktop is started and enabled for your WSL terminal [more details](https://learn.microsoft.com/windows/wsl/tutorials/wsl-containers#install-docker-desktop). Open the repository folder in Visual Studio Code. You can do this from the command prompt:

```shell
code .
```

Once Visual Studio Code is launched, you should see a popup allowing you to click on the button **Reopen in Container**.

![Reopen in Container](assets/images/vscode-reopen-in-container.png)

If you don't see the popup, open the Visual Studio Code Command Palette to execute the command. There are three ways to open the command palette:

- For Mac users, use the keyboard shortcut ⇧⌘P
- For Windows and Linux users, use Ctrl+Shift+P
- From the Visual Studio Code top menu, navigate to View -> Command Palette.

Once the command palette is open, search for `Dev Containers: Rebuild and Reopen in Container`.

![WSL Ubuntu](assets/images/vscode-reopen-in-container-command.png)

### 3. Create a new environment

The environment name should be less than 18 characters and must be comprised of lower-case, numeric, and dash characters (for example, `dotnetwebapp`).  The environment name is used for resource group naming and specific resource naming. Also, select a password for the admin user of the database.

If not using PowerShell 7+, run the following command:

```shell
pwsh
```

Run the following commands to set these values and create a new environment:

```pwsh
azd env new dotnetwebapp
```

Substitute the environment name with your own value.

By default, Azure resources are sized for a "development" mode. If doing a Production deployment, set the `AZURE_ENV_TYPE` to `prod` using the following code:

```pwsh
azd env set AZURE_ENV_TYPE prod
```

### 4. Log in to Azure

Before deploying, you must be authenticated to Azure and have the appropriate subscription selected.  To authenticate:

```pwsh
azd auth login
```

```pwsh
Connect-AzAccount
```

Each command will open a browser allowing you to authenticate.  To list the subscriptions you have access to:

```pwsh
Get-AzSubscription
```

To set the active subscription:

```pwsh
$AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
azd env set AZURE_SUBSCRIPTION_ID $AZURE_SUBSCRIPTION_ID
Set-AzContext -SubscriptionId $AZURE_SUBSCRIPTION_ID
```

### 5. Select a region for deployment

The application can be deployed in either a single region or multi-region manner. You can find a list of available Azure regions by running the following Azure CLI command.

> ```pwsh
> (Get-AzLocation).Location
> ```

Set the `AZURE_LOCATION` to the primary region:

```shell
azd env set AZURE_LOCATION westus3
```

If doing a multi-region deployment, set the `AZURE_LOCATION2` to the secondary region:

```shell
azd env set AZURE_LOCATION2 eastus
```

Make sure the secondary region is a paired region with the primary region (`AZURE_LOCATION`). Paired regions are required to support some Azure features; for example, [geo-zone-redundant storage (GZRS) failover](https://learn.microsoft.com/azure/storage/common/storage-disaster-recovery-guidance). For a full list of region pairs, see [Azure region pairs](https://learn.microsoft.com/azure/reliability/cross-region-replication-azure#azure-cross-region-replication-pairings-for-all-geographies). We have validated the following paired regions.

| AZURE_LOCATION | AZURE_LOCATION2 |
| ----- | ----- |
| westus3 | eastus |
| westeurope | northeurope |
| australiaeast | australiasoutheast |

### 6. Provision the application

Run the following command to create the infrastructure (about 15-minutes to provision):

```pwsh
azd provision --no-prompt
```

**Create App Registrations**

Relecloud devs have automated the process of creating Azure
AD resources that support the authentication features of the
web app. They use the following command to create two new
App Registrations within Azure AD. The command is also
responsible for saving configuration data to Key Vault and
App Configuration so that the web app can read this data
(about 3-minutes to register).

```sh
./infra/scripts/postprovision/call-create-app-registrations.sh
```

**Set Configuration**

Relecloud devs have automated the process of configuring the environment.

```sh
./infra/scripts/predeploy/call-set-app-configuration.sh
```

### 7. Deploy the application

Run the following command to deploy the code to the created infrastructure (about 4-minutes to deploy):

```shell
azd deploy
```

If you are doing a multi-region deployment, you must also deploy the code to the secondary region (about 4-minutes to deploy):

```shell
SECONDARY_RESOURCE_GROUP=$(azd env get-values --output json | jq -r .secondary_resource_group)
azd env set AZURE_RESOURCE_GROUP $SECONDARY_RESOURCE_GROUP
azd deploy
```

The provisioning and deployment process can take anywhere from 20 minutes to over an hour, depending on system load and your bandwidth.


### 8. Open and use the application

Use the following to find the URL for the Proseware application that you have deployed:

```shell
azd env get-values --output json | jq -r .WEB_URI
```

![screenshot of Relecloud app home page](assets/images/WebAppHomePage.png)

It takes approximately 5 minutes for the Azure App Service to respond to requests using the code deployed during step 6.

### 9. Teardown

To tear down the deployment, run the following command:

```shell
azd down
```

Your Azure subscription will retain your deployment request as a stateful object.
If you would like to change the Azure region for this deployment you will need to
delete the deployment by running the following command.

```
az deployment delete --name $myEnvironmentName
```

> You can list all deployments with the following command
> `az deployment sub list --query "[].name" -o tsv`

### Local Development

Relecloud developers use Visual Studio to develop locally and they co-share
an Azure SQL database for local dev. The team chooses this workflow to
help them practice early integration of changes as modifying the
database and other shared resources can impact multiple workstreams.

To connect to the shared database the dev team uses connection strings
from Key Vault and App Configuration Service. Devs use the following
script to retrieve data and store it as
[User Secrets](https://learn.microsoft.com/aspnet/core/security/app-secrets?view=aspnetcore-6.0&tabs=windows)
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
1. Setup the **Relecloud.Web** project User Secrets
    1. Right-click on the **Relecloud.Web** project
    1. From the context menu choose **Manage User Secrets**
    1. From a command prompt run the bash command

        <table>
        <tr>
        <td>PowerShell</td>
        <td>

        ```ps1
        pwsh -c "Set-ExecutionPolicy Bypass Process; .\infra\localDevScripts\getSecretsForLocalDev.ps1 -g '$myEnvironmentName-rg' -Web"
        ```

        </td>
        </tr>
        <tr>
        <td>Bash</td>
        <td>
                
        ```bash
        chmod +x ./infra/localDevScripts/getSecretsForLocalDev.sh
        ./infra/localDevScripts/getSecretsForLocalDev.sh -g "$myEnvironmentName-rg" --web
        ```

        </td>
        </tr>
        </table>

    1. Copy the output into the `secrets.json` file for the **Relecloud.Web**
    project.

1. Setup the **Relecloud.Web.Api** project User Secrets
    1. Right-click on the **Relecloud.Web.Api** project
    1. From the context menu choose **Manage User Secrets**
    1. From a command prompt run the bash command

        <table>
        <tr>
        <td>PowerShell</td>
        <td>

        ```ps1
        pwsh -c "Set-ExecutionPolicy Bypass Process; .\infra\localDevScripts\getSecretsForLocalDev.ps1 -g '$myEnvironmentName-rg' -Api"
        ```

        </td>
        </tr>
        <tr>
        <td>Bash</td>
        <td>
                
        ```bash
        ./infra/localDevScripts/getSecretsForLocalDev.sh -g "$myEnvironmentName-rg" --api
        ```

        </td>
        </tr>
        </table>

    1. Copy the output into the `secrets.json` file for the 
    **Relecloud.Web.Api** project.

1. Right-click the **Relecloud** solution and pick **Set Startup Projects...**
1. Choose **Multiple startup projects**
1. Change the dropdowns for *Relecloud.Web* and *Relecloud.Web.Api* to the action of **Start**.
1. Click **Ok** to close the popup
1. Add your IP address to the SQL Database firewall as an allowed connection by using the following script

    <table>
    <tr>
    <td>PowerShell</td>
    <td>

    ```ps1
    pwsh -c "Set-ExecutionPolicy Bypass Process; .\infra\localDevScripts\addLocalIPToSqlFirewall.ps1 -g '$myEnvironmentName-rg'"
    ```

    </td>
    </tr>
    <tr>
    <td>Bash</td>
    <td>
            
    ```bash
    chmod +x ./infra/localDevScripts/addLocalIPToSqlFirewall.sh
    ./infra/localDevScripts/addLocalIPToSqlFirewall.sh -g "$myEnvironmentName-rg"
    ```

    </td>
    </tr>
    </table>

1. When connecting to Azure SQL database you'll connect with your Azure AD account.
Run the following command to give your Azure AD account permission to access the database.

    <table>
    <tr>
    <td>PowerShell</td>
    <td>

    ```ps1
    pwsh -c "Set-ExecutionPolicy Bypass Process; .\infra\localDevScripts\makeSqlUserAccount.ps1 -g '$myEnvironmentName-rg'"
    ```

    </td>
    </tr>
    <tr>
    <td>Bash</td>
    <td>
            
    ```bash
    chmod +x ./infra/localDevScripts/makeSqlUserAccount.sh
    ./infra/localDevScripts/makeSqlUserAccount.sh -g "$myEnvironmentName-rg"
    ```

    </td>
    </tr>
    </table>

1. Press F5 to start debugging the website

> These steps grant access to SQL server in the primary resource group.
> You can use the same commands if you want to test with the secondary resource
> group by changing the ResourceGroup parameter "-g" to "$myEnvironmentName-secondary-rg"

## Additional links

- [Known issues](known-issues.md)
- [Developer patterns](simulate-patterns.md)
- [Find additional resources](additional-resources.md)
- [Report security concerns](SECURITY.md)
- [Find Support](SUPPORT.md)
- [Contributing](CONTRIBUTING.md)

## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft's privacy statement. Our privacy statement is located at https://go.microsoft.com/fwlink/?LinkId=521839. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.

### Telemetry Configuration

Telemetry collection is on by default.

To opt out, run the following command `azd env set ENABLE_TELEMETRY` to `false` in your environment.
