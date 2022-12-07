## Simulating the patterns

The application uses design patterns to improve the reliability and performance efficiency. The implementation lets you test the design patterns included in the code.

### Retry pattern

Transient faults or errors are temporary service interruptions due to network hops and multi-tenancy traffic. We call them "transient" faults because they typically resolve themselves within a few seconds. The best approach for handling transient faults is with the retry pattern, not an exception. When a 500 error occurs, the retry pattern sends follow-up requests to the API. The retries are often successful.

For more information, see:

- [Transient fault handling](https://learn.microsoft.com/aspnet/aspnet/overview/developing-apps-with-windows-azure/building-real-world-cloud-apps-with-windows-azure/transient-fault-handling)
- [Retry pattern](https://learn.microsoft.com/azure/architecture/patterns/retry)

We built an app configuration setting that lets you simulate and test a transient failure.
The setting is called `Api:App:RetryDemo`. We've included this configuration in the deployable code. The `Api:App:RetryDemo` setting throws a 503 error when the end user sends an HTTP request to the web app API. `Api:App:RetryDemo` has an editable value setting that determines the intervals between 503 errors. A value of 2 generates a 503 error for every other request. A value of 1 has no intervals and generates a 503 error for every request.

We recommend collecting telemetry for this test. We've configured Application Insights to collect telemetry. When the value of `Api:App:RetryDemo` is 2, the first request to the application API generates a 503 error. But the retry pattern sends a second request that is successful and generates a 200 response. We recommend using the Application Insights Live Metrics features to the HTTP responses in near-realtime. App Insights can up to a minute to aggregate the data it receives, and failed requests might not appear right away.

For more information, see:

- [Application Insights Live Metrics](/azure/azure-monitor/app/live-stream)
- [Visual Studio and Application Insights live telemetry](/azure/azure-monitor/app/visual-studio)

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
