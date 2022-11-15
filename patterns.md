## Simulating the patterns

Here are some things you can try to see how these patterns support the availability and scalability of this solution in Azure.

### Retry and Circuit Breakers

Transient errors are temporary service interruptions due to network hops and multi-tenancy traffic. Transient failures typically resolve themselves. The best approach for handling is with the retry pattern, not an exception. When a 500 error occurs, the retry pattern sends another request to API. If it's a transient failure, the retry is often successful. For more information, see [Transient Fault Handling](https://learn.microsoft.com/aspnet/aspnet/overview/developing-apps-with-windows-azure/building-real-world-cloud-apps-with-windows-azure/transient-fault-handling)

We built an app configuration setting that lets you simulate a transient error.
The setting is called `Api:App:RetryDemo`. We've included this configuration in the deployable code. The `Api:App:RetryDemo` setting throws a 503 error when a user HTTP request is sent to the web app API.  `Api:App:RetryDemo` has a value setting that determines intervals between 503 errors. You can edit the value of the setting to determine the intervals. A value of 1 has no intervals. It generates a 503 error for every request. A value of 2 generates a 503 error for every other request.

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
