## Simulating the patterns

Here are some things you can try to see how these patterns support the availability and scalability of this solution in Azure.

### Retry and Circuit Breakers

Transient faults or errors are temporary service interruptions due to network hops and multi-tenancy traffic. We call them "transient" faults because they typically resolve themselves within a few seconds. The best approach for handling transient faults is with the retry pattern, not an exception. When a 500 error occurs, the retry pattern sends follow-up requests to the API. The retries are often successful. For more information, see [transient fault Handling](https://learn.microsoft.com/aspnet/aspnet/overview/developing-apps-with-windows-azure/building-real-world-cloud-apps-with-windows-azure/transient-fault-handling)

We built an app configuration setting that lets you simulate and test a transient failure.
The setting is called `Api:App:RetryDemo`. We've included this configuration in the deployable code. The `Api:App:RetryDemo` setting throws a 503 error when the end user sends an HTTP request to the web app API. `Api:App:RetryDemo` has a value setting that you can edit to determines intervals between 503 errors. A value of 2 generates a 503 error for every other request. A value of 1 has no intervals. It generates a 503 error for every request.

![image of Configuration Explorer in the App Configuration Service blade on the Azure Portal](./assets/Guide/Simulating_AppConfigSvcConfigurationExplorer.png)

Based on the bicep templates provided this setting
`App:RelecloudApi:BaseUri` is automatically set to the correct URL so
that your web app will work every time you deploy to a new environment.
But what if this was a manual step? Let's replace the ".net" value in
this configuration with ".com" and observe the behavior. Click save and
use the Azure Portal to restart the front-end App Service so that this
value is reloaded.

![image of App Service restart confirmation dialog](./assets/Guide/Simulating_AppServiceRestart.png)

We recommend collecting telemetry for this test. We've configured Application Insights to collect telemetry. When the value of `Api:App:RetryDemo` is 2, the first request to the application API generates a 503 error. But the retry pattern sends a second request that is successful and generates a 200 response.

### Cache Aside Pattern

The cache aside pattern enables us to offload read queries to SQL server and it also provides a layer of redundancy that can keep parts of our application running in the event of issue with Azure SQL Database. We can observe this behavior in App Insights by testing two different pages.

First, visit the "Upcoming Concerts" page and refresh the page a couple
of times. The first time the page is loaded the web API app will send a
request to SQL server, but the following requests will go to Azure Cache
for Redis.

![image of App Insights shows connection to SQL server to retrieve data](./assets/Guide/Simulating_AppInsightsRequestWithSqlServer.png)

In this screenshot above we see a connection was made to SQL server and
that this request took 742ms.

![image of App Insights shows request returns data without SQL](./assets/Guide/Simulating_AppInsightsRequestWithoutSql.png)

In the next request we see that the API call was only 55ms because it
didn't have to connect to SQL Server and instead used the data from
Azure Cache for Redis.

![image of Azure Cache for Redis Console lists all keys](./assets/Guide/Simulating_RedisConsoleListKeys.png)

Using the (PREVIEW) Redis Console we can see this data stored in Redis.

![image of Azure Cache for Redis Console shows data for upcoming concerts](./assets/Guide/Simulating_RedisConsoleShowUpcomingConcerts.png)
