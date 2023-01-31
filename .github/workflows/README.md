# GitHub Actions
GitHub Actions makes it easy to automate your software workflows with world-class CI/CD. You can build, test, and deploy your code right from GitHub.

In this directory you'll find files that you can use to get started with this sample in your repo and files that we use to maintain the quality of this sample by automating our test cycles.

## Sample workflows for your environment
The file `azure-dev.yml` is one that you can use to configure this sample for continuous integration testing to a shared dev environment. To get started with this file you will want to uncomment the trigger section at the top which defines when this GitHub Action workflow should run.

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
- `scheduled-azure-dev.yml`: Deploys the Azure resources in this sample so that we can check for quality  characteristics and ensure that the latest tooling recommendation are compatible.
- `scheduled-azure-teardown.yml`: In the event of a workflow failure, we use this file to teardown any remaining Azure resources to limit the costs that accrue as part of our testing cycles.

### Validation Script
As part of this sample the dev team is monitoring for scenarios such as race conditions and intermittent issues which could cause the deployment to fail. As these issues are identified we update the `validateDeployment.sh`, and the mirror file `validateDeployment.ps1` which are also part of our engineering process. We use these files to validate characteristics of a successful deployment. These files will evolve as the sample evolves to help us ensure the quality of the solution.