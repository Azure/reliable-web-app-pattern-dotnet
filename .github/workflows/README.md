# GitHub Actions
GitHub Actions makes it easy to automate your software workflows with world-class CI/CD. You can build, test, and deploy your code right from GitHub.

In this directory you'll find files that you can use to get started with this sample in your repo and files that we use to maintain the quality of this sample by automating our test cycles.

## Sample workflows for your environment
There are a few sample workflows in this directory that can help you get started with your own CI/CD process. Of course every environment is different, you should adjust these according to your needs. Below is a list of the files and the functionality they provide.  See the section below on how to configure your environment.

### Primary workflows
- `build.yml` - This workflow builds the projects in the solution, and runs the unit tests included with each project. If no errors are found, it will create two build artifacts, one for the binaries created and one for deploying the infrastructure for the application.

- `deploy.yml` - This workflow deploys the infrastructure, and binaries to a given environment and optionally runs an integration test if provided.

- `tear-down.yml` - This workflow removes the infrastructure in a given environnement.

### The next three workflows use the previous workflows to validate and deploy the application.

- `pull-request.yml` - This workflow runs after pull requests are submitted to the main branch and makes sure preliminary tests pass.

- `continuous-integration.yml` - This workflow runs once a day completely deletes the dev environment and re-deploys it to make sure the development environment matches the code.

- 'continuous-delivery.yml` - This workflow builds and deploys the code every time there is a change to the main branch.  First it deploys to the dev environment, and if approved will continue to production.

## Configure GitHub
You will need to configure your Azure and Github environments for these workflows to be able to build and deploy to your subscription.

1. Create a service principal (app registration) in Azure that has contributor permissions to your subscription. And configure your Github account to use [OpenID Connect to authenticaticate with Azure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure). 
    - One easy way to accomplish this is to use `azd pipeline config` command to create the app registration. 
    - In some scenarios you might not have permission to do so and you might need to ask your Azure admin to do this for you.
    - Note that you can also use a user assigned managed identity for this purpose also.

1. Configure federated credentials for your service principal, which is used to authenticate with GitHub without using any secrets.  You can do this in the _Certificates & Secrets_ section, under the _Federated credentials_ tab. 
    - Create one set of credentials for each environment you are using, in this case one for pr, dev, and prod as follows:
        - `Organization` - Your GitHub account or organization name if the repo is in a organization account.
        - `Repository` - Name of your repository ex _reliable-web-app-pattern-donet_
        - `Entity type` - Select Environment
        - `Based on select` - On per environment we are using [pr, de, prod]
    
    Your subject identifiers should look like: `repo:<your repo name>/reliable-web-app-pattern-dotnet:environment:dev`

1. In your GitHub repository create three environments one for pr, dev, and prod. These environments define protection rules, secrets and variables for deployment.
    - Navigate to your repository's settings, and select _Environments_ in the left menu.
    - click on the _New environment_ button and add all three to your repository. 
    - For now the only change you want to make is for the _prod_ environment, check the _Required reviewers_ checkbox and pick at least one person who has write permission to the repository. This is to prevent the continuous delivery workflow from deploying to production before a manual approval.  (If you are very confident in your automated tests, you can skip this.)
    
1. Now we need to configure your repository's variables in GitHub. Repository variables are shared among all environments and you can add to or override these in the environment specific section. Navigate to your repository's settings section, select _Secrets and variables_ on the left hand menu and click on _Actions_.  Add the following variables, either under the shared _Repository variables_ section or _Environment variables_ section per environment.
    - `AZURE_CLIENT_ID` - This is the client ID of the service principal that you created earlier in Azure. Best practice is to have a different principal at least for production, to minimize the access level each one has.
    - `AZURE_TENANT_ID` - This is the id of your Azure Active Directory tenant, usually shared among all environments.
    - `AZURE_SUBSCRIPTION_ID` - Subscription ID for where you are deploying your infrastructure. Best practice would be to have a separate subscription for production.
    - `PRINCIPAL_TYPE` - This identifies the type of principal that is deploying the application, it is used during deployment to adjust permissions if a user is deploying the environment. For all github deployments use the value **ServicePrincipal**
    - `AZURE_ENV_NAME` - Environment name for azd's use, best to have the same value as your GitHub environment name. (ex. dev)
    - `AZURE_LOCATION` - Region where you are deploying your application (ex. westus3)
    - `AZURE_RESOURCE_GROUP` - Name of the resource group you want the application deployed to, best to have a different one per environment.  Note that pr environment also appends the pr number to the value to allow multiple pull requests at the same time.


## Other considerations
Your devOps process should be customized to automate the build, test, and deployment steps specific to your business needs.

We recommend these following considerations to expand on the `azure-dev.yml` sample.

- You may want to review `scheduled-azure-dev.yml` to see how to add more steps such as validation testing
- You may want multiple workflows defined in different files for different purposes
    - Consider database lifecycle management
    - Consider quality testing processes (e.g. integration testing)

## Engineering workflows
This repository also contains workflows that are part of our engineering process to ensure the quality of this sample. The following files are used by the team:

- `add-issues-to-project.yml`: Uses a GitHub Action to automate the process of adding an item that was created in this repository to our central project management board to improve visibility and work item tracking.
- `scheduled-azure-dev.yml`: Deploys the Azure resources in this sample so that we can check for quality characteristics and ensure that the latest tooling recommendation are compatible.
- `scheduled-azure-teardown.yml`: In the event of a workflow failure, we use this file to teardown any remaining Azure resources to limit the costs that accrue as part of our testing cycles.

### Validation Script
As part of this sample the dev team is monitoring for scenarios such as race conditions and intermittent issues which could cause the deployment to fail. As these issues are identified we update the `validateDeployment.sh`, and the mirror file `validateDeployment.ps1` which are also part of our engineering process. We use these files to validate characteristics of a successful deployment. These files will evolve as the sample evolves to help us ensure the quality of the solution.