# Developer Experience

The dev team uses Visual Studio and they integrate directly with Azure resources when building the code. The team chooses this workflow to so they can integration test with Azure before their code reaches the QA team.

> **NOTE**
>
> This developer experience is only supported for development deployments. Production deployments
> use network isolation and do not allow devs to connect from their workstation.

Most configurations in the project are stored in Azure App Configuration with secrets saved into Azure Key Vault. To connect to these resources from a developer workstation you need to complete the following steps.

1. Add your identity to the Azure SQL resource
1. Set up front-end web app configuration
1. Set up back-end web app configuration

To support this workflow the following steps will store data in [User Secrets](https://learn.microsoft.com/aspnet/core/security/app-secrets?view=aspnetcore-6.0&tabs=windows) because the code is configured so that these values override configurations and secrets saved in Azure.

> For your convenience, we use Dev Containers which provide a fully-featured development environment for executing these commands. If you're not using the Dev Container, we recommend installing the required [dependencies](./prerequisites.md) to ensure the success of these commands.

## Authenticate with Azure

1.  If you are not using PowerShell 7+, run the following command (you can use [$PSVersionTable.PSVersion](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_powershell_editions) to check your version):

    ```sh
    pwsh
    ```

1. Connect to Azure

    ```pwsh
    Import-Module Az.Resources
    ```

    ```pwsh
    Connect-AzAccount
    ```

1. Set the subscription to the one you want to use (you can use [Get-AzSubscription](https://learn.microsoft.com/powershell/module/az.accounts/get-azsubscription?view=azps-11.3.0) to list available subscriptions):

    ```pwsh
    $AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
    ```

    ```pwsh
    Set-AzContext -SubscriptionId $AZURE_SUBSCRIPTION_ID
    ```

## Add your identity to the Azure SQL resource

1. Run the following script to automate the process in docs [Configure and manage Microsoft Entra authentication with Azure SQL](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-configure?view=azuresql&tabs=azure-powershell)

    ```pwsh
    ./infra/scripts/devexperience/call-make-sql-account.ps1
    ```

## Set up front-end web app configuration

    ```pwsh
    $appConfigurationUri = ((azd env get-values --output json | ConvertFrom-Json).APP_CONFIG_SERVICE_URI)
    ```

    ```pwsh
    cd src/Relecloud.Web.CallCenter
    ```

    ```pwsh
    dotnet user-secrets clear
    ```

    ```pwsh
    dotnet user-secrets set "App:RelecloudApi:BaseUri" "https://localhost:7242"
    ```

    ```pwsh
    dotnet user-secrets set "App:AppConfig:Uri" $appConfigurationUri
    ```

    ```pwsh
    cd ../..
    ```

## Set up back-end web app configuration

    ```pwsh
    cd src/Relecloud.Web.CallCenter.Api
    ```

    ```pwsh
    dotnet user-secrets clear
    ```
    
    ```pwsh
    dotnet user-secrets set "App:AppConfig:Uri" $appConfigurationUri
    ```
