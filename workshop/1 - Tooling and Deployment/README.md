## 1 - Tooling and Deployment

The following detailed deployment steps assume you are using a Dev Container inside Visual Studio Code.

> For your convenience, we use Dev Containers with a fully-featured development environment. If you prefer to use Visual Studio, we recommend installing the necessary [dependencies](../../prerequisites.md) and skip to the deployment instructions starting in [Step 3](#3-log-in-to-azure).

### 1. Clone the repo

> For Windows users, we recommend using Windows Subsystem for Linux (WSL) to [improve Dev Container performance](https://code.visualstudio.com/remote/advancedcontainers/improve-performance).

```pwsh
wsl
```

Clone the repository from GitHub into the WSL 2 filesystem using the following command:

```shell
git clone https://github.com/Azure/reliable-web-app-pattern-dotnet.git
cd reliable-web-app-pattern-dotnet
```

### 2. Open Dev Container in Visual Studio Code

If required, ensure Docker Desktop is started and enabled for your WSL terminal [more details](https://learn.microsoft.com/windows/wsl/tutorials/wsl-containers#install-docker-desktop). Open the repository folder in Visual Studio Code. You can do this from the command prompt:

```shell
code .
```

Once Visual Studio Code is launched, you should see a popup allowing you to click on the button **Reopen in Container**.

![Reopen in Container](../images/1-Tooling%20and%20Deployment/vscode-reopen-in-container.png)

If you don't see the popup, open the Visual Studio Code Command Palette to execute the command. There are three ways to open the command palette:

- For Mac users, use the keyboard shortcut ⇧⌘P
- For Windows and Linux users, use Ctrl+Shift+P
- From the Visual Studio Code top menu, navigate to View -> Command Palette.

Once the command palette is open, search for `Dev Containers: Rebuild and Reopen in Container`.

![WSL Ubuntu](../images/1-Tooling%20and%20Deployment//vscode-reopen-in-container-command.png)

### 3. Log in to Azure

Before deploying, you must be authenticated to Azure and have the appropriate subscription selected. Run the following command to authenticate:

If you are not using PowerShell 7+, run the following command (you can use [$PSVersionTable.PSVersion](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_powershell_editions) to check your version):

```shell
pwsh
```

```pwsh
Import-Module Az.Resources
```

```pwsh
Connect-AzAccount -UseDeviceAuthentication 
```

Set the subscription to the one you want to use selecting from the list available subscriptions on the terminal. Enter the number corresponding to the subscription you do wish to use.

Use the next command to login with the Azure Dev CLI (AZD) tool:

```pwsh
azd auth login
```


### 4. Create a new environment

Next we provide the AZD tool with variables that it uses to create the deployment. The first thing we initialize is the AZD environment with a name.

The environment name should be less than 18 characters and must be comprised of lower-case, numeric, and dash characters (for example, `dotnetwebapp`).  The environment name is used for resource group naming and specific resource naming.

By default, Azure resources are sized for a development deployment. If doing a production deployment, see the [production deployment](../../prod-deployment.md) instructions for more detail.

```pwsh
azd env new <pick_a_name>
```

Select the subscription that will be used for the deployment:

```pwsh
azd env set AZURE_SUBSCRIPTION_ID $AZURE_SUBSCRIPTION_ID
```

Set the `AZURE_LOCATION` (Run `(Get-AzLocation).Location` to see a list of locations):

```pwsh
azd env set AZURE_LOCATION <pick_a_region>
```

### 5. Create the Azure resources and deploy the code

Run the following command to create the Azure resources and deploy the code (about 15-minutes to complete):

```pwsh
azd up
```

### 6. Open and use the application

Use the URL displayed in the console output to launch the web application that you have deployed:

![screenshot of web app home page](../images/1-Tooling%20and%20Deployment//WebAppHomePage.png)

You can learn more about the web app by reading the [Pattern Simulations](../../demo.md) documentation.

### Appendix A (To be run only after completing the workshop)

Run the following command to tear down the deployment:

```pwsh
azd down --purge --force
```