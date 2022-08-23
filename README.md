# Scalable Web App Pattern

This repository provides resources to help developers build a Scalable web app on Azure. A Scalable Web App is a set of services, code, and infrastructure deployed in Azure that applies practices from the Well-Architected Framework. This pattern is shared with three components to help you use Azure to build a web app that follows Microsoft's recommended guidance for achieving reliability, scalability, and security in the cloud.

3 components of the Scalable web app are:
* [A Guide](https://docs.microsoft.com/dotnet/api/system.notimplementedexception) that demonstrates the guidance and explains the context surrounding the decisions that were made to build this solution
* A sample solution that demonstrates how these decisions were implemented as code
* A sample deployment pipeline with bicep resources that demonstrate how the infrastructure decisions were implemented

# Getting started

1. Pre-requisites

    > The createAppRegistrations.sh script is a bash script built to run on WSL for Windows users


    - [WSL 2](https://docs.microsoft.com/windows/wsl/install)
        - Windows users only
            ```powershell
            wsl --install
            ```

    - [Azure Developer CLI](https://aka.ms/azure-dev/install)
        - Windows:
            ```powershell
            powershell -ex AllSigned -c "Invoke-RestMethod 'https://aka.ms/install-azd.ps1' | Invoke-Expression"
            ```
        - Linux/MacOS:
            ```
            curl -fsSL https://aka.ms/install-azd.sh | bash
            ```
    - [Azure CLI (2.38.0+)](https://docs.microsoft.com/cli/azure/install-azure-cli)
    

2. Provision the Azure resources
    ```sh
    environmentName=relecloudresourcesdev
    azd provision -e $environmentName --no-prompt
    ```

3. Setup Azure App Registrations

    This will create the resources in Azure AD that enable your web app to support authentication and authorization.

    ```sh
    ./infra/createAppRegistrations.sh -g "$environmentName-rg"
    ```

4. Deploy the code
    
    ```sh
    azd deploy --no-prompt
    ```
