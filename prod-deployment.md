# Steps to deploy the Network Isolated implementation
This section describes the deployment steps for the reference implementation of a reliable web application pattern with .NET on Microsoft Azure. These steps guide you through using the jump host that is deployed when performing a network isolated deployment because access to resources will be restricted from public network access and must be performed from a machine connected to the vnet.

![Diagram showing the network focused architecture of the reference implementation.](./assets/images/reliable-web-app-prod-network.svg)

## Prerequisites

We recommend that you use a Dev Container to deploy this application.  The requirements are as follows:

- [Azure Subscription](https://azure.microsoft.com/pricing/member-offers/msdn-benefits-details/).
- [Visual Studio Code](https://code.visualstudio.com/).
- [Docker Desktop](https://www.docker.com/get-started/).
- [Permissions to register an application in Microsoft Entra ID](https://learn.microsoft.com/azure/active-directory/develop/quickstart-register-app).
- Visual Studio Code [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers).

If you do not wish to use a Dev Container, please refer to the [prerequisites](prerequisites.md) for detailed information on how to set up your development system to build, run, and deploy the application.

> **Note**
>
> These steps are used to connect to a Linux jump host where you can deploy the code. The jump host is not designed to be a build server. You should use a devOps pipeline to manage build agents and deploy code into the environment. Also note that for this content the jump host is a Linux VM. This can be swapped with a Windows VM based on your organization's requirements.

## Steps to deploy the reference implementation

The following detailed deployment steps assume you are using a Dev Container inside Visual Studio Code.

### 1. Log in to Azure

Before deploying, you must be authenticated to Azure and have the appropriate subscription selected. Run the following command to authenticate:

```pwsh
Import-Module Az.Resources
```

```pwsh
Connect-AzAccount
```

To list the subscriptions you have access to:

```pwsh
Get-AzSubscription
```

```pwsh
$AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
```

```pwsh
Set-AzContext -SubscriptionId $AZURE_SUBSCRIPTION_ID
```

```pwsh
azd auth login
```

Run the following commands to set these values and create a new environment:

```pwsh
azd env new rwa1_1
```

To deploy the dev version:

```pwsh
azd env set ENVIRONMENT prod
```

```pwsh
azd env set AZURE_SUBSCRIPTION_ID $AZURE_SUBSCRIPTION_ID
```

Set the `AZURE_LOCATION` to the primary region:

```pwsh
azd env set AZURE_LOCATION uksouth
```

Set the `AZURE_SECONDARY_LOCATION` to the primary region:

```pwsh
azd env set AZURE_SECONDARY_LOCATION northeurope
```

### 2. Provision the app

Run the following command to create the infrastructure (about 45-minutes to provision):

```pwsh
azd provision
```

### 3. Upload the code to the jump host

> **WARNING**
>
> When the prod deployment is performed the Key Vault resource will be deployed with public network access enabled. This allows the reader to access the Key Vault to retrieve the username and password for the jump host. This also allows you to save data created by the create-app-registration script directly to the Key Vault. We recommend reviewing this approach with your security team as you may want to change this approach. One option to consider is adding the jump host to the domain, disabling public network access for Key Vault, and running the create app-registration script from the jump host.

To retrieve the generated password:

1. Retrieve the username and password for your jump host:

    - Locate the Hub resource group in the Azure Portal.
    - Open the Azure Key Vault from the list of resources.
    - Select **Secrets** from the menu sidebar.
    - Select **Jumphost--AdministratorPassword**.
    - Select the currently enabled version.
    - Press **Show Secret Value**.
    - Note the secret value for later use.
    - Repeat the proecess for the **Jumphost--AdministratorUsername** secret.

1. Start a new terminal from your dev container and run the following commands to create a bastion tunnel to the jump host:

    <!-- requires AZ cli login -->
    <!-- might need to remove key -->
    <!-- todo - make folder on server -->
    <!-- todo - installation of Az module failed -->

    ```shell
    bastionName=<enter-the-data>
    resourceGroupName=<enter-the-data>
    username=azureadmin
    targetResourceId=<enter-the-data>

    az network bastion tunnel --name $bastionName --resource-group $resourceGroupName --target-resource-id $targetResourceId --resource-port 22 --port 50022
    ```

    <!--  az network bastion ssh --name $bastionName --resource-group $resourceGroupName --target-resource-id $targetResourceId --auth-type "password" --username $username -->

1. Use the following SCP command to upload the code to the jump host:
    ```shell
    scp -r -P 50022 * azureadmin@127.0.0.1:web-app-pattern/
    ```

    > **NOTE**
    >
    > Use the password you retrieved  Key Vault to authenticate the SCP command. Replace the `azureadmin` portion of the command with the username from Key Vault as needed.


1. Use the following SCP command to send the AZD environment to the jump host:
    ```shell
    scp -r -P 50022 ./.azure azureadmin@127.0.0.1:web-app-pattern/
    ```

1. Run the following command to start a shell session on the jump host:

    ```shell
    ssh azureadmin@127.0.0.1 -p 50022
    ```

### 4. Authenticate to Azure

1. Start a PowerShell session:

    ```shell
    pwsh
    ```

1. [Sign in to Azure PowerShell interactively](https://learn.microsoft.com/powershell/azure/authenticate-interactive):

    ```pwsh
    Connect-AzAccount -UseDeviceAuthentication
    ```

1. [Sign in to azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/reference#azd-auth-login):

    ```shell
    azd auth login --use-device-code
    ```

<!-- todo - set default subscription for pwsh context -->

### 5. Deploy the code

<!-- todo - cd into web-app-pattern directory -->
<!-- todo - chmod+x on scripts
chmod +x ./infra/scripts/predeploy/call-set-app-configuration.sh
chmod +x ./infra/scripts/postdeploy/show-webapp-uri.sh
 -->

 <!-- todo - confirm ResourceToken in script -->

1. Deploy the code from the jump host:

    ```shell
    azd deploy
    ```

    It takes approximately 5 minutes to deploy the code.

    For a multi-region deployment, you must also deploy the code to the secondary region following these same steps on the secondary jump host.

    > **WARNING**
    > In some scenarios, the DNS entries for resources secured with Private Endpoint may have been cached incorrectly. It can take up to 10-minutes for the DNS cache to expire.

1. Use the URL displayed in the consol output to launch the Relecloud application that you have deployed:

    ![screenshot of Relecloud app home page](assets/images/WebAppHomePage.png)

### 6. Teardown

1. Close your SSH session:

```shell
exit
```

1. Close your background shell that opened the bastion tunnel with Ctrl+C.

1. To tear down the deployment, run the following command from your dev container to remove all resources from Azure and the jump host:

```pwsh
azd down --purge --force
```

