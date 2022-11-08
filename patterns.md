## Simulating the patterns

Here are some things you can try to see how these patterns support the availability and scalability of this solution in Azure.

### Retry and Circuit Breakers

These patterns improve the reliability of the solution by attempting to
resolve transient errors that can surface when making an API call. To
observe this, we'll change the baseUri setting in App Configuration and
examine the App Insights logs to observe that API calls were retried and
when the circuit is open that we can also observe the "fail fast"
behavior.

First, open the Azure App Configuration blade in the Azure Portal.
Scroll down through the tabs and find the "Configuration Explorer" so
you can see the settings that the web app uses.

![image of Configuration Explorer in the App Configuration Service blade on the Azure Portal](./assets/Guide/Simulating_AppConfigSvcConfigurationExplorer.png)

Based on the bicep templates provided this setting
`App:RelecloudApi:BaseUri` is automatically set to the correct URL so
that your web app will work every time you deploy to a new environment.
But what if this was a manual step? Let's replace the ".net" value in
this configuration with ".com" and observe the behavior. Click save and
use the Azure Portal to restart the front-end App Service so that this
value is reloaded.

![image of App Service restart confirmation dialog](./assets/Guide/Simulating_AppServiceRestart.png)

After the web app is restarted, we can click on the "Upcoming" menu link
and see that all of the concert data has disappeared. Even though our
data is cached in Redis we can see that the web front-end needs access
to the web API app to receive that data.

![image of App Service restart confirmation dialog](./assets/Guide/Simulating_UpcomingConcertsPage.png)

And in App Insights we can see that this is not an error the web app
could recover from so the Circuit Breaker pattern allowed the user to
see a "fail fast" experience because the circuit was open.

![image of request error in Application Insights shows that the circuit is now open](./assets/Guide/Simulating_AppInsightsTransationDetails.png)

Let's re-open the Azure App Configuration Explorer and fix that setting
before moving to the next step. Edit the `App:RelecloudApi:BaseUri`
and replace the ".com" part of the Uri with ".net" as it was originally
configured.

![image of Configuration Explorer in the App Configuration Service blade on the Azure Portal](./assets/Guide/Simulating_AppConfigSvcConfigurationExplorer.png)

And we must also restart the web app again for this new setting to take effect.

![image of App Service restart confirmation dialog](./assets/Guide/Simulating_AppServiceRestart.png)

### Cache Aside Pattern

The cache aside pattern enables us to offload read queries to SQL server
and it also provides a layer of redundancy that can keep parts of our
application running in the event of issue with Azure SQL Database. We
can observe this behavior in App Insights by testing two different
pages.

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
