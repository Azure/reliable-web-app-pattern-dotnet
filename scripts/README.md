# Testing scripts
These scripts are used by the engineering team to accelerate the testing process through deployment automation.

## Workflow

1. From terminal in the devcontainer start powershell

    ```sh
    pwsh
    ```

1. Install the required PowerShell modules 

    ```pwsh
    Install-Module Az
    ```

    ```pwsh
    Import-Module Az
    ```
    
1. Validate your connection settings

    ```pwsh
    Get-AzContext
    ```

    ```pwsh
    azd config get defaults.subscription
    ```

    * If you are not authenticated then run the following to set your account context.

        ```pwsh
        Connect-AzAccount
        ```
        
        ```pwsh
        azd auth login
        ```

    * If you need to change your default subscription.

        ```pwsh
        Set-AzContext -Subscription {your_subscription_id}
        ```
        
        ```pwsh
        azd config set defaults.subscription {your_subscription_id}
        ```

1. Start a provision

    > It is encouraged to use a distinct name for each deployment
    
    ```pwsh
    ./scripts/setup.ps1 -NotIsolated -Development -CommonAppServicePlan -SingleLocation -Name reledev7 
    ```

    <!-- ./scripts/setup.ps1 -Hub -Isolated -Development -NoCommonAppServicePlan -SingleLocation -Name rele231129v1 -->

1. Run a deployment

    ```pwsh
    azd deploy
    ```

1. Clean up a provisioned environment

    > Find the full name of the application resource group to be supplied as the value for *ResourceGroup* param

    ```pwsh
    ./scripts/cleanup.ps1 -AsJob -ResourceGroup rg-reledev7-dev-westus3-application
    ```