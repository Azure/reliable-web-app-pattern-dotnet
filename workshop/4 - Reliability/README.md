# 4 - Reliability

A reliable web application is one that is both resilient and available. Resiliency is the ability of the system to recover from failures and continue to function. Availability is a measure of whether your users can access your web application when they need to. You should use the Retry and Circuit Breaker patterns as critical first steps toward improving application reliability. 

These design patterns introduce self-healing qualities and help your application maximize the reliability features of the cloud. Here are our reliability recommendations.

## Use the retry pattern for transient faults

Transient faults are temporary issues that typically resolve without intervention within a short period. These faults can stem from momentary network glitches, brief unavailability of a service, or timeouts that occur when a service is overwhelmed with requests. They're transient because they typically resolve themselves in a few seconds.

The Retry pattern is a technique for handling temporary service interruptions. This pattern entails a strategy for retrying an operation that has failed due to a transient fault. By implementing a series of retries with an incremental delay between attempts, the system can overcome temporary disruptions and ensure continuity of service.

### Adding the Retry Pattern to our sample

Before we begin, copy the `.azure` from our previous deployment from chapter three, to our `azd-sample` in the current chapter. 

In the sample, open the `src` and the `AppConfigurationFolder` to change both `appsettings.json` and  `program.cs`

*Verifying this with stakeholders for the next steps*

Go to the `appsettings.json`, add the following key immediately after the **AllowedHosts** key:

```json
"Api": {
    "App": {
        "RetryDemo":  "2"
    }
}
```


To test the application locally. Run the application using `dotnet run`

You might need to make calls to a dependency that isn't an Azure service or doesn't support the Retry pattern natively. In that case, you should use the [Polly library](https://github.com/App-vNext/Polly) to implement the Retry pattern. Polly is a .NET resilience and transient-fault-handling library.

Let's implement custom retry policies to the project to handle any transient communication faults.


 Add the Polly NuGet package to **AppConfigurationReader**. From **Solution Explorer**. 

1. From the **Console**, add the following command.

    ``dotnet add package Polly.Contrib.WaitAndRetry --version 1.1.1``

1. Open the **Program.cs** file from the **AppConfigurationReader** project.
1. Add the following using statements to the top of the file:

    ```csharp
    using Polly;
    using Polly.Contrib.WaitAndRetry;
    using Polly.Extensions.Http;
    ```

1. Add the following method to the **Startup** class:

    ```csharp
    private static IAsyncPolicy<HttpResponseMessage> GetRetryPolicy()
    {
        var delay = Backoff.DecorrelatedJitterBackoffV2(TimeSpan.FromMilliseconds(500), retryCount: 3);

        return HttpPolicyExtensions
            .HandleTransientHttpError()
            .WaitAndRetryAsync(delay);
    }
    ```

    The `GetRetryPolicy` method returns a `IAsyncPolicy<HttpResponseMessage>` that can be used to retry HTTP requests. The `HandleTransientHttpError` method tells Polly to retry the HTTP request if the response is a transient HTTP error. The `WaitAndRetryAsync` method tells Polly to retry the HTTP request using a specified delay between retries.

*Verifying this with stakeholders for the next steps*

1. Now, we have to tell application for a `HttpClient` that is used to communicate to the **Weather Forecast** service to use the retry policy.


1. Add the following code to the end of the `builder.Services.AddSingleton<WeatherForecastService>();` method:

    ```csharp
    .AddPolicyHandler(GetRetryPolicy());
    ```

    The `AddPolicyHandler` method adds the retry policy to the `HttpClient` that is injected into the `WeatherForecastService` class. That `HttpClient` is subsequently used to communicate with the **Weather Forecast** service.

1. Run the application locally again, and it will handle the transient errors successfully.


## Circuit Breaker pattern

To ensure reliability, it is recommended to combine the Retry pattern with the Circuit Breaker pattern. While the Retry pattern is effective in handling transient faults, the Circuit Breaker pattern is designed to handle non-transient faults. By implementing the Circuit Breaker pattern, you can prevent your application from continuously invoking a service that is currently unavailable, thus improving overall reliability.

### Adding the Circuit Breaker Pattern to our sample

You can implement the circuit breaker pattern with Polly as follows:

1. Open the **Program.cs** file from the **AppConfigurationReader** project.
1. Add the following method

    ```csharp
    private static IAsyncPolicy<HttpResponseMessage> GetCircuitBreakerPolicy()
    {
        return HttpPolicyExtensions
            .HandleTransientHttpError()
            .OrResult(msg => msg.StatusCode == System.Net.HttpStatusCode.NotFound)
            .CircuitBreakerAsync(5, TimeSpan.FromSeconds(30));
    }
    ```

    The `GetCircuitBreakerPolicy` method returns a `IAsyncPolicy<HttpResponseMessage>` that can be used to implement the Circuit Breaker pattern. The `HandleTransientHttpError` method tells Polly to retry the HTTP request if the response is a transient HTTP error. The `OrResult` method tells Polly to retry the HTTP request if the response is a 404 Not Found. The `CircuitBreakerAsync` method tells Polly to break circuit if the HTTP request fails 5 times in 30 seconds.

*Verifying this with stakeholders for the next steps*

1. Now, we have to tell application for a `HttpClient` that is used to communicate to the **Weather Forecast** service to use the retry policy.


1. Add the following code to the end of the `builder.Services.AddSingleton<WeatherForecastService>();` method:

    ```csharp
    .AddPolicyHandler(GetCircuitBreakerPolicy());
    ```

    The `AddPolicyHandler` method adds the retry policy to the `HttpClient` that is injected into the `WeatherForecastService` class. That `HttpClient` is subsequently used to communicate with the **Weather Forecast** service.

1. Run the application locally again, and it will handle the transient errors successfully.

1. Run the application locally again, this time if 5 exceptions occur within 30 seconds, the circuit will break and the application will stop trying to communicate with the **Weather Forecast** service.

1. When you call it more than 5 times you will start to see a `Polly.CircuitBreaker.BrokenCircuitException` exception in the output window.

    ![Screenshot of circuit breaker exception](../images/4-Reliability/circuit-breaker.png)


### Checking the Main Relecloud Application to check Azure service SDKs and client libraries

Most Azure services and client SDKs have a built-in retry mechanism. You should use the built-in retry mechanism for Azure services to expedite the implementation. Let's see how the retry pattern is implemented in the main sample using Entity Framework Core's built-in retry mechanism.

1. Select the main **Relecloud** solution.
1. Open the **Relecloud.CallCenter.Api** project's **Startup.cs** file.
1. Browse to the `AddConcertContextServices` method. This method configures the Entity Framework Core context for the application.
1. Look at the `services.AddDbContextPool<ConcertDataContext>` call on the following code:

    ```csharp
    services.AddDbContextPool<ConcertDataContext>(options => options.UseSqlServer(sqlDatabaseConnectionString,
        sqlServerOptionsAction: sqlOptions =>
        {
            sqlOptions.EnableRetryOnFailure(
            maxRetryCount: 5,
            maxRetryDelay: TimeSpan.FromSeconds(3),
            errorNumbersToAdd: null);
        }));
    ```

    The `EnableRetryOnFailure` method enables the built-in retry mechanism for Entity Framework Core. The default retry policy is to retry up to 6 times with a 2-second delay between retries. You can change the default retry policy by passing a `MaxRetryCount` and `MaxRetryDelay` to the `EnableRetryOnFailure` method.

Now we'll use the Azure App Configuration's SDK to add a retry policy to communication with the Azure App Configuration service.


1. Open the **Program.cs** file from the same project.
1. Browse to the `builder.Configuration.AddAzureAppConfiguration` call. It should be on line 11.
1. Inspect the following code onto the end of the `ConfigureKeyVault` method.

    ```csharp
    .ConfigureClientOptions(options =>
    {
        options.Retry.MaxRetries = 5;
        options.Retry.MaxDelay = TimeSpan.FromSeconds(3);
    });
    ```

    The `ConfigureClientOptions` method configures the retry policy for the Azure App Configuration SDK. The default retry policy is to retry up to 3 times with a 1-second delay between retries. You can change the default retry policy by passing a `MaxRetries` and `MaxDelay` to the `ConfigureClientOptions` method.

    The entire Azure App Configuration configuration should look like this:

    ```csharp
    builder.Configuration.AddAzureAppConfiguration(options =>
    {
        options
            .Connect(new Uri(builder.Configuration["Api:AppConfig:Uri"]), new DefaultAzureCredential())
            .ConfigureKeyVault(kv =>
            {
                // Some of the values coming from Azure App Configuration are stored Key Vault, use
                // the managed identity of this host for the authentication.
                kv.SetCredential(new DefaultAzureCredential());
            })
            .ConfigureClientOptions(options =>
            {
                options.Retry.MaxRetries = 5;
                options.Retry.Delay = TimeSpan.FromSeconds(3);
            });
    });
    ```    

## Next Steps

Next up, let's look at how to make sure our application stays secure in the [Part 5 - Security](../5%20-%20Security/README.md) module.
