## Simulating the patterns

The application uses design patterns to improve the reliability and performance efficiency. The implementation lets you test the design patterns included in the code.

### Retry pattern

Transient faults are temporary service interruptions due to network hops and multi-tenancy traffic. We call them "transient" faults because they typically resolve themselves within a few seconds. The best approach for handling transient faults is with the retry pattern, not an exception. When a 500 error occurs, the retry pattern sends follow-up requests to the API because we expect the retries will be successful.

For more information, see:

- [Transient fault handling](https://learn.microsoft.com/aspnet/aspnet/overview/developing-apps-with-windows-azure/building-real-world-cloud-apps-with-windows-azure/transient-fault-handling)
- [Retry pattern](https://learn.microsoft.com/azure/architecture/patterns/retry)

We built an app configuration setting that lets you simulate and test a transient failure from the Web API. The setting is called `Api:App:RetryDemo`. We've included this configuration in the deployable code. The `Api:App:RetryDemo` setting throws a 503 error when the end user sends an HTTP request to the web app API. `Api:App:RetryDemo` has an editable setting that determines the intervals between 503 errors. A value of 2 generates a 503 error for every other request.

Follow these steps to set up this test:

1. Create a new key-value in App Configuration.
    - Go to App Configuration in the Azure Portal
    - Select your app configuration resource
    - Navigate to the "Configuration explorer" by clicking the link in the left-hand blade under "Operations"
    - Click the "+ Create" button and choose "Key-value"
    - Enter the following data:
    

    |Name|Value|
    |-----|-----|
    |*Key*|Api:App:RetryDemo|
    |*Value*|2|

1. Restart the API web app App Service
    - Go to the API web app App Service
    - Navigate to the "Overview" blade
    - Click the "Restart" button at the top of the page.
  
  > It will take a few minutes for the App Service to restart. When it restarts, the application will use the `Api:App:RetryDemo` configuration. You need to restart the App Service any time you update a configuration value.

We recommend collecting telemetry for this test. We've configured Application Insights to collect telemetry. When the value of `Api:App:RetryDemo` is 2, the first request to the application API generates a 503 error. But the retry pattern sends a second request that is successful and generates a 200 response. We recommend using the Application Insights Live Metrics features to view the HTTP responses in near-realtime.

> App Insights can up to a minute to aggregate the data it receives, and failed requests might not appear right away in the Failures view.

To see the Retry Pattern in action you can click throughout the Relecloud website and should not see any impact to the user's ability to purchase a concert ticket. However, in App Insights you should see the 503 error happens for 50% of the requests sent to the Web API.

For more information, see:

- [Application Insights Live Metrics](/azure/azure-monitor/app/live-stream)
- [Visual Studio and Application Insights live telemetry](/azure/azure-monitor/app/visual-studio)

> We recommend you cleanup by deleting the `Api:App:RetryDemo` setting.

### Circuit Breaker Pattern

The Retry Pattern is often used with the Circuit Breaker pattern because the Retry process only handles transient errors. As a side-effect this negatively impacts the user's perception of performance if a real error happens. The Circuit Breaker pattern addresses this by analyzing the health of your system and is used to bypass the Retry Pattern when the system is unhealthy. This improves the user's perception performance because they don't have to wait around everytime there's an error. The Circuit Breaker pattern also gives resources that are failing a chance to recover by blocking new requests that would cause an error.

This is particularly useful when deploying a high-volume Web API web app. During deployment all of the front-end web app calls are expected to fail. And, when the circuit breaker pattern stops new requests, this gives the Web API web app a chance to get started and fully loaded before the full load of front-end users returns.

We built an app configuration setting that lets you simulate and test a failure from the Web API. The setting is called `Api:App:RetryDemo`. We've included this configuration in the deployable code. The `Api:App:RetryDemo` setting throws a 503 error when the end user sends an HTTP request to the web app API. `Api:App:RetryDemo` has an editable setting that determines the intervals between 503 errors. A value of 1 has no intervals and generates a 503 error for every request.

Following these steps to set up this test:

1. Create a new key-value in App Configuration.
    - Go to App Configuration in the Azure Portal
    - Select your app configuration resource
    - Navigate to the "Configuration explorer" by clicking the link in the left-hand blade under "Operations"
    - Click the "+ Create" button and choose "Key-value"
    - Enter the following data:
    

    |Name|Value|
    |-----|-----|
    |*Key*|Api:App:RetryDemo|
    |*Value*|1|

1. Restart the API web app App Service
    - Go to the API web app App Service
    - Navigate to the "Overview" blade
    - Click the "Restart" button at the top of the page.
  
  > It will take a few minutes for the App Service to restart. When it restarts, the application will use the `Api:App:RetryDemo` configuration. You need to restart the App Service any time you update a configuration value.

To see these recommendations in action you can click on the "Upcoming Concerts" page in the Relecloud web app. Since the Web API is returning an error for every request you will see that the front-end applied the Retry Pattern up to three times to request the data for this page. If you reload the "Upcoming Concernts" page you can see that the Circuit Breaker has detected these three errors and that the circuit is now open. When the circuit is open there are no new requests sent to the Web API web app for 30 seconds. This presents a fail-fast behavior to our users and also reduces the number of requests sent to the unhealthy Web API web app so it has more time to recover.

> Note that App Insights can up to a minute to aggregate the data it receives, and failed requests might not appear right away in the Failures view.

For more information, see:

- [Application Insights Live Metrics](/azure/azure-monitor/app/live-stream)
- [Visual Studio and Application Insights live telemetry](/azure/azure-monitor/app/visual-studio)

> We recommend you cleanup by deleting the `Api:App:RetryDemo` setting.

### Cache-Aside Pattern

The cache-aside pattern enables us to limit read queries to SQL server. It also provides a layer of redundancy that can keep parts of our application running in the event of issue with Azure SQL Database.

For more information, see [cache-aside pattern](https://learn.microsoft.com/azure/architecture/patterns/cache-aside).

We can observe this behavior in App Insights by testing two different pages. First, visit the "Upcoming Concerts" page and refresh the page a couple of times. The first time the page is loaded the web API app will send a request to SQL server, but the following requests will go to Azure Cache for Redis.

![image of App Insights shows connection to SQL server to retrieve data](./assets/Guide/Simulating_AppInsightsRequestWithSqlServer.png)

In this screenshot above we see a connection was made to SQL server and that this request took 742ms.

![image of App Insights shows request returns data without SQL](./assets/Guide/Simulating_AppInsightsRequestWithoutSql.png)

In the next request we see that the API call was only 55ms because it didn't have to connect to SQL Server and instead used the data from Azure Cache for Redis.

![image of Azure Cache for Redis Console lists all keys](./assets/Guide/Simulating_RedisConsoleListKeys.png)

Using the (PREVIEW) Redis Console we can see this data stored in Redis.

![image of Azure Cache for Redis Console shows data for upcoming concerts](./assets/Guide/Simulating_RedisConsoleShowUpcomingConcerts.png)

## Next Step
- [Understand service level objectives and cost](slo-and-cost.md)