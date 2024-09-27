# 3 - Cost Optimization

Cost optimization principles balance business goals with budget justification to create a cost-effective web application. This pillar is about reducing unnecessary expenses and improving operational efficiencies.

We'll explore 4 techniques for cost optimization. 
- Correctly sizing the resources for your business needs. 
- Computing service-level agreements. 
- Aiming for scalable costs. 
- To delete and cleanup what you no longer need.

In this portion of the workshop, we'll be working with a simple Blazor Server application deployed to Azure App Service that reads a value from Azure App Configuration.

![Screenshot from the sample application](../images/3-Cost%20Optimization/sample-application.png)

## Right size resources

You can use bicep parameters to specify Azure resource deployment configurations. We'll use a small sample contained in the **azd-sample** folder and PowerShell to illustrate this technique. If you are not logged in Azure, before following the guide, [click for instructions to login](../1%20-%20Tooling%20and%20Deployment/README.md#3-log-in-to-azure).


1. Open the *PowerShell terminal* and navigate to the **azd-sample** directory.
1. Run the following command to initialize an Azure Developer CLI (azd) environment. _(Replace `<env-name>` below the desired environment name, remember use valid chars, this will reflect in the website URL.)_

    ```powershell
    $costEnvironmentName = '<env-name>'
    azd init -e $costEnvironmentName
    ```
1. Run the following command to set an azd environment variable. This variable will be passed into the bicep file as a parameter.

    ```powershell
    azd env set IS_PROD false
    azd env set AZURE_RESOURCE_GROUP "$costEnvironmentName-cost-rg"
    ```

1. A new directory named **.azure** has now been created under the **azd-sample** directory. It will have a subdirectory with the same name as the azd environment you created above. (For example **.azure\matt**). Within that directory will be a filed named **.env**. This file contains the environment variables you set above and needed by the Azure Developer CLI to provision the Azure resources. It should look something like the following:

    ```text
    AZURE_ENV_NAME="workshop-rwa"
    AZURE_RESOURCE_GROUP="workshop-rwa-cost-rg"
    IS_PROD="false"
    ```

    It also contains other environment variables needed by the Azure Developer CLI to successfully deploy the application, such as the Azure subscription ID and the Azure region to deploy to.

1. In Visual Studio or VS Code, open up the **azd-sample\infra** folder. This folder contains the bicep files that provision the Azure resources for this sample application.

    Variables can be used in bicep files to help provision the resources needed for particular needs. In this case we'll look at provisioning resources for production versus development.

1. Open the **main.parameters.json** file. Note that it is expecting an environment variable of the name `IS_PROD` and will map that to the bicep variable name `isProd`.

1. Now open up the **main.bicep** file. Near the top of the file, the `isProd` variable is defined as an incoming parameter. Further down, on line 35, it is passed to the **resources.bicep** file as a parameter.

1. Open the **resources.bicep** file. `isProd` again is defined as a parameter at the top of the file. On line 62, it is used to make a determination of what SKU level the Azure App Service should be provisioned at.

    ```bicep
    var appServicePlanSku = (isProd) ? 'P1v3' : 'B1'
    ```

1. Now let's provision the Azure resources and deploy the sample application. In the PowerShell terminal, make sure you're still in the **azd-sample** directory and run the following command:

    ```powershell
    azd up
    ```

    You will be prompted to pick a subscription and Azure region. Select your subscription option, and pick **EastUS** for the region.

2. When the provisioning and deployment is finished, the URL for the sample application will be displayed in the terminal. Open that URL in a browser. You should see the sample application running.

3. You can also view the Azure resources in the Azure portal. Open the portal and browse for resource groups. The name of the resource group will start with  **<USERNAME>-cost-rg**.

4. Open the App Service Plan within the resource group. You should see that it is provisioned with a **B1** SKU.

    ![Screenshot of the App Service Plan](../images/3-Cost%20Optimization/app-service-plan.png)

## Aim for scalable costs

You want to have your resources scale up and down as needed. Azure App Service has built-in autoscaling capabilities. Let's add that to our sample application.

1. In Visual Studio or VS Code, open the **autoscale.bicep** file from the **azd-sample\infra** folder.
1. Note how it defines scaling rules both with a trigger and an action to take when the trigger is met. For example, if the CPU percentage is greater than a threshold, increase the number of instances by 1.
1. Let's implement the autoscaling as part of our azd provisioning. Add the following to the **resources.bicep** file.

    ```bicep
    module webAppAutoScale 'autoscale.bicep' = {
        name: 'deploy-${webAppServicePlan.name}-autoscale'
        params: {
        appServicePlanName: webAppServicePlan.name
        location: location
        isProd: isProd
        tags: tags
        }
    }
    ```

1. In a PowerShell terminal, in the **\azd-sample** directory, run the following to update the azd environment.

    ```powershell
    azd env set IS_PROD true
    ```

1. Now, run the following to provision the autoscaling.

    ```powershell
    azd provision
    ```

1. Open up the same App Service Plan as before in the Azure portal (or just refresh your browser if you already have it open). You should see that it is provisioned with a **P1v3** SKU.

    ![Screenshot of the App Service Plan](../images/3-Cost%20Optimization/app-service-plan-p1v3.png)

1. Click on **Scale out (App Service Plan)** in the left navigation menu, under Settings. You should see that autoscaling is enabled with a "Rules Based" scale out method.  Click on **Manage rules based scaling** to see the scaling rules.

    ![Screenshot of the scale out settings](../images/3-Cost%20Optimization/scale-out.png)

> Note: Due to limits of the free subscription, the autoscaling may not work. However, it will work if you have a paid subscription.

## Cost Optimization in the Relecloud Tickets Application

Analyzing the Relecloud Ticket application, it is possible to understand how production applications do apply Cost Optimizations in Azure in the Code. Helping Relecloud to operate the platform with cost efficiency and smooth with Azure and Bicep configurations.

First, open the bicep file for App Service plan for the main application, the file can be found at ```infra\core\hosting\app-service-plan.bicep```.

In the file, we do have the maps to the Service Plans for each plan, for each step while scaling or descaling. This goes from the most basic plan in B1 until a Premium plan in P3v3.

```bicep
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/patterns-configuration-set#example
var environmentConfigurationMap = {
  B1:   { name: 'B1',   tier: 'Basic',          size: 'B1',   family: 'B'   }
  B2:   { name: 'B2',   tier: 'Basic',          size: 'B2',   family: 'B'   }
  B3:   { name: 'B3',   tier: 'Basic',          size: 'B3',   family: 'B'   }
  P0v3: { name: 'P0v3', tier: 'PremiumV3',      size: 'P0v3', family: 'Pv3' }
  P1v3: { name: 'P1v3', tier: 'PremiumV3',      size: 'P1v3', family: 'Pv3' }
  P2v3: { name: 'P2v3', tier: 'PremiumV3',      size: 'P2v3', family: 'Pv3' }
  P3v3: { name: 'P3v3', tier: 'PremiumV3',      size: 'P3v3', family: 'Pv3' }
  S1:   { name: 'S1',   tier: 'Standard',       size: 'S1',   family: 'S'   }
  S2:   { name: 'S2',   tier: 'Standard',       size: 'S2',   family: 'S'   }
  S3:   { name: 'S3',   tier: 'Standard',       size: 'S3',   family: 'S'   }
}
```

In the next section of the Bicep script, we delineate the auto-scaling rules for the application. 

The script is structured to first retrieve the properties defined within the Bicep configuration. Following this, it adjusts the scaling parameters based on predefined trigger points to ensure optimal performance. 

```bicep
resource autoScaleRule 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (autoScaleSettings != null) {
  name: '${name}-autoscale'
  location: location
  tags: tags
  properties: {
    targetResourceUri: appServicePlan.id
    enabled: true
```

This condition specifies the capacity boundaries for scaling operations. The minimum and default capacity values are determined by a conditional check on zoneRedundant. Being the minCapacity and maxCapacity setted in the autoScaleSettings.

```bicep
    profiles: [
      {
        name: 'Auto created scale condition'
        capacity: {
          minimum: string(zoneRedundant ? 3 : autoScaleSettings!.minCapacity)
          maximum: string(autoScaleSettings!.maxCapacity)
          default: string(zoneRedundant ? 3 : autoScaleSettings!.minCapacity)
        }
```
Let's look how the rule defines a metric-based trigger for auto-scaling for a better service.

Starting with, specifing that the CPU usage percentage of the app service plan is monitored. The metric is evaluated over a period of 5 minutes (PT5M). 

If the average CPU percentage over a 10-minute window (PT10M) exceeds the defined threshold, the scale action is triggered. 

The action specified is to increase the instance count, with a cooldown period of 10 minutes before another scale action can be initiated.

 This rule ensures that the application scales up responsively when the CPU load increases, maintaining performance while avoiding unnecessary scaling.

```bicep
        rules: [
          {
            metricTrigger: {
              metricResourceUri: appServicePlan.id
              metricName: 'CpuPercentage'
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: autoScaleSettings.?scaleOutThreshold ?? defaultScaleOutThreshold
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
          }

```

The same happens with the down-scale. Which if the CPU is under a certain porcentage, it will descale the the count by one, and cooldowns the selection for ten minutes before acting the rule again.

```bicep
          {
            metricTrigger: {
              metricResourceUri: appServicePlan.id
              metricName: 'CpuPercentage'
              timeGrain: 'PT5M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: autoScaleSettings.?scaleInThreshold ?? defaultScaleInThreshold
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: string(1)
              cooldown: 'PT10M'
            }
```

## Compute service level agreements

Picking the right SKU for your Azure resources based on the service level agreements (SLA) you need is another way to optimize costs. Let's look at how to compute SLAs.

Our management has decided they want a 99.98% SLA for our sample application. Let's see how we can compute the SLA for our entire app based on the Azure resources we've provisioned.

1. Our application consists of Azure App Service and Azure App Configuration.
  1. The SLA for Azure App Service is 99.95%.
  1. The SLA for Azure App Configuration is 99.9%
1. To get a composite SLA for an application composed of multiple services, multiple the SLAs together.

  ```text
  99.95% * 99.9% = 99.85%
  ```

The 99.85% SLA is not good enough for management. That's 13 hours of downtime per year! Let's see if we can improve that.

The obvious way would be to add another Azure region. If Azure resource goes down a backup in another region will be able to cover. The formula to calculate the SLA for multiple regions is:

$$ 1 - (1 - N)^R $$ 

Where **N** is the SLA for a single region and **R** is the number of regions. Let's see how that works for our sample application.

  ```
  1 - (1 - 0.9985)^2 = 99.99%
  ```

But in order for 2 regions to operate as one, you need a traffic manager or load balancer of some sort in front of them. If we use Azure Front Door, with an SLA of 99.99% we then get:

  ```
  99.99% * 99.99% = 99.98%
  ```

And that's exactly the 99.98% uptime our management wanted.

For our Relecloud Concerts application, we have devised a strategy on how to utilize various regions to meet the Service Level Agreement (SLA). If you’re interested in understanding more about these calculations and our regional usage strategy, follow this [link](/assets/sla-calculation.md) to learn more.

## Next Steps

Next, we will explore how to enhance the resilience of our web application. This involves implementing strategies to ensure our application remains functional and accessible, even in the event of failures. Dive into the [Part 4 - Reliability](../4%20-%20Reliability/README.md) module.
