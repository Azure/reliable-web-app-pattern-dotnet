# Known issues
This document helps with troubleshooting and provides an introduction to the most requested features, gotchas, and questions.

## Work from our backlog
These issues relate to content in our sample that we're working to modify. Open issues are provided for further detail and status updates.

### Data consistency for multi-regional deployments

This sample includes a feature to deploy to two Azure regions. The feature is intended to support the high availability scenario by deploying resources in an active/passive configuration. The sample currently supports the ability to fail-over web-traffic so requests can be handled from a second region. However it does not support data synchronization between two regions. 

This can result in users losing trust in the system when they observe that the system is online but their data is missing. The following issues represent the work remaining to address data synchronization.

Open issues:
* [Implement multiregional Azure SQL](https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/44)
* [Implement multiregional Storage](https://github.com/Azure/reliable-web-app-pattern-dotnet/issues/122)

## Troubleshooting
The following topics are intended to help readers with our most commonly reported issues.

* **Cannot execute shellscript `/bin/bash^M: bad interpreter`**
    This error happens when Windows users checked out code from a Windows environment
    and try to execute the code from Windows Subsystem for Linux (WSL). The issue is
    caused by Git tools that automatically convert `LF` characters based on the local
    environment.

    Run the following commands to change the windows line endings to linux line endings:

    ```bash
    sed "s/$(printf '\r')\$//" -i ./infra/createAppRegistrations.sh
    sed "s/$(printf '\r')\$//" -i ./infra/validateDeployment.sh
    sed "s/$(printf '\r')\$//" -i ./infra/localDevScripts/addLocalIPToSqlFirewall.sh
    sed "s/$(printf '\r')\$//" -i ./infra/localDevScripts/getSecretsForLocalDev.sh
    sed "s/$(printf '\r')\$//" -i ./infra/localDevScripts/makeSqlUserAccount.sh
    ```

* **Error: no project exists; to create a new project, run 'azd init'**
    This error is most often reported when users try to run `azd` commands before running the `cd` command to switch to the directory where the repo was cloned.

    > You may need to `cd` into the directory you cloned to run this command.

* **The deployment 'relecloudresources' already exists in location**
    This error most often happens when trying a new region with the same for `$myEnvironment`

    When the `azd provision` command runs it creates a deployment resource in your subscription. You must delete this deployment before you can change the Azure region.

    > Please see the [teardown instructions](README.md#clean-up-azure-resources) to address this issue.
