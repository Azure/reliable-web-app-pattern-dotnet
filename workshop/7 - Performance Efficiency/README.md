# 7- Performance Efficiency

Performance efficiency is the ability of a workload to scale and meet the demands placed on it by users in an efficient manner. In cloud environments, a workload should anticipate increases in demand to meet business requirements.

## The Cache-Aside pattern

The Cache-Aside pattern is a technique that's used to manage in-memory data caching. It reduces the request response time and can lead to increased response throughput. This efficiency reduces the number of horizontal scaling events, making the app more capable of handling traffic bursts. It also improves service availability by reducing the load on the primary data store and decreasing the likelihood of service outages.

Let's implement the Cache-Aside pattern in our application.

1. Open the **7 - Performance Efficiency\start\Relecloud.sln** solution.
1. From the **Solution Explorer**, right-click on the **Relecloud.Web.Api** project and select **Manage NuGet Packages**.
1. Search for **Microsoft.Extensions.Caching.StackExchangeRedis** and install the package.
1. Open the **Startup.cs** of the **Relecloud.Web.Api** project and browse to the `AddDistributedSession` method.
1. Delete the code inside that method.
1. Add code to read the Azure Redis Cache connection string from the configuration settings.

    ```csharp
    var redisCacheConnectionString = Configuration["App:RedisCache:ConnectionString"];
    ```
1. Add code to use Azure Redis if the connection string contains a value

    ```csharp
    if (!string.IsNullOrWhiteSpace(redisCacheConnectionString))
    {
        // If we have a connection string to Redis, use that as the distributed cache.
        // If not, ASP.NET Core automatically injects an in-memory cache.
        services.AddStackExchangeRedisCache(options =>
        {
            options.Configuration = redisCacheConnectionString;
        });
    }
    ```

1. Add the following code to handle if a connection string is not present, use the built-in distributed cache.

    ```csharp
    else
    {
        services.AddDistributedMemoryCache();
    }
    ```

1. Now we want to cache some of the most used data in our application, and that is getting concerts from the database. Open the **SqlDatabaseConcertRepository.cs** file found in the **Services/SqlDatabaseConcertRepository** folder of the **Relecloud.Web.Api** project.
1. Create a private class-level variable to hold the distributed cache.

    ```csharp
    private readonly IDistributedCache cache;
    ```

1. Update the constructor so it accepts an `IDistributedCache` parameter. The finished version shoud look like this:

    ```csharp
    public SqlDatabaseConcertRepository(ConcertDataContext database, IDistributedCache cache)
    {
        this.database = database;
        this.cache = cache;
    }
    ```

1. Any time data is modified in the database, the cache needs to be cleared. Update the `CreateConcertAsync` method to include the cache removal. The final method should look like this:

    ```csharp
    public async Task<CreateResult> CreateConcertAsync(Concert concert)
    {
        database.Add(newConcert);
        await this.database.SaveChangesAsync();

        // Clear the cache
        this.cache.Remove(CacheKeys.UpcomingConcerts);

        return CreateResult.SuccessResult(newConcert.Id);
    }
    ```

1. Add the same cache clearing to `UpdateConcertAsync`. The final method should look like this:

    ```csharp
    public async Task<UpdateResult> UpdateConcertAsync(Concert existingConcert)
    {
        database.Update(existingConcert);
        await database.SaveChangesAsync();

        this.cache.Remove(CacheKeys.UpcomingConcerts);

        return UpdateResult.SuccessResult();
    }
    ```

1. The same thing needs to happen when a concert is deleted. Add the following code to the `DeleteConcertAsync` method immediately after the `SaveChangesAsync` call:

    ```csharp
    this.cache.Remove(CacheKeys.UpcomingConcerts);
    ```

1. Now that the cache is cleared when any data modification occurs, we want to put data into the cache when data is read from the database and the cache is empty. Browse to the `GetUpcomingConcertsAsync` method.
1. We'll read from the cache by using `GetStringAsync`. Add the following code immediately under the `IList<Concert>? concerts;` definition.

    ```csharp
    var concertsJson = await this.cache.GetStringAsync(CacheKeys.UpcomingConcerts);
    ```

1. If the returned `concertsJson` has a value, we can deserialize that into the `concerts` variable. Add the following code to do so:

    ```csharp
    if (concertsJson != null)
    {
        concerts = JsonSerializer.Deserialize<IList<Concert>>(concertsJson);
    }
    ```

1. If there is nothing in the `concertsJson` variable, and thus nothingn in the cache read the data from the database as normal. Put the existing data retrieval code inside an else statement:

    ```csharp
    else 
    {
         concerts = await this.database.Concerts.AsNoTracking()
            .Where(c => c.StartTime > DateTimeOffset.UtcNow && c.IsVisible)
            .OrderBy(c => c.StartTime)
            .Take(count)
            .ToListAsync();
    }
    ```

1. Now that we have the data, we want to put it into the cache. Add the following code immediately after the `concerts = await this.database.Concerts.AsNoTracking()` line:

    ```csharp
    concertsJson = JsonSerializer.Serialize(concerts);
    var cacheOptions = new DistributedCacheEntryOptions
    {
        AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1)
    };
    await this.cache.SetStringAsync(CacheKeys.UpcomingConcerts, concertsJson, cacheOptions);
    ```

    This code serializes the data into JSON, sets a cache expiration time of 1 hour, and then stores the JSON data in the cache.

1. The finished `GetUpcomingConcertsAsync` function should look like this:

    ```csharp
    public async Task<IList<Concert>> GetUpcomingConcertsAsync(int count)
    {
        IList<Concert>? concerts;

        var concertsJson = await this.cache.GetStringAsync(CacheKeys.UpcomingConcerts);
        if (concertsJson != null)
        {
            concerts = JsonSerializer.Deserialize<IList<Concert>>(concertsJson);
        }
        else
        {
            concerts = await this.database.Concerts.AsNoTracking()
                .Where(c => c.StartTime > DateTimeOffset.UtcNow && c.IsVisible)
                .OrderBy(c => c.StartTime)
                .Take(count)
                .ToListAsync();

            concertsJson = JsonSerializer.Serialize(concerts);
            var cacheOptions = new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1)
            };
            await this.cache.SetStringAsync(CacheKeys.UpcomingConcerts, concertsJson, cacheOptions);
        }

        return concerts ?? new List<Concert>();
    }
    ```

1. You can see this working locally. Make sure both the **Web** and **Api** applications are set as the multiple start-up projects.
1. Run the applications and browse to **Upcoming Concerts**.
1. The first time you browse to it, the concerts may take a bit of time to load. Subsequent loads should be much faster.

## Caching in the Reliable Web App reference application

You should use a single cache instance to support multiple data types rather than using a single instance for each data type.

The reference implementation uses a single Azure Cache for Redis instance to store session state for the front-end web app and the back-end web app. The front-end web app stores two pieces of data in session state. It stores the cart and the Microsoft Authentication Library (MSAL) token.

1. You can see all of this by using the **Relecloud** solution you already have open.
1. Open the **Relecloud.Web** project.
1. Open the **Startup.cs** file and browse to the `AddAzureCacheForRedis` method.

    ```csharp
    private void AddAzureCacheForRedis(IServiceCollection services)
    {
        if (!string.IsNullOrWhiteSpace(Configuration["App:RedisCache:ConnectionString"]))
        {
            services.AddStackExchangeRedisCache(options =>
            {
                options.Configuration = Configuration["App:RedisCache:ConnectionString"];
            });
        }
        else
        {
            services.AddDistributedMemoryCache();
        }
    }
    ```

    If a connection string is present, Azure Cache for Redis is used. Otherwise, an in-memory cache is used.
1. Browse to the `AddAzureAdServices` method in the **Startup.cs** file.
1. Look for the line that reads `if (string.IsNullOrEmpty(Configuration["App:RedisCache:ConnectionString"]))`. It is here you can see how MSAL is set to use in-memory caching or Azure Cache for Redis to manage tokens.
1. Open the **CartController.cs** file found in the **Controllers** folder of the **Relecloud.Web** project.
1. Browse to the `SetCardData` method. Here you can see the session data get set. It seamlessly uses Azure Cache for Redis when available.

## Cleaning up

Thank you for attending this workshop.  We hope you learned something and feel more comfortable tackling the patterns that are used in enterprise web applications.  You can now clean up the resources that you used:

### Cleaning up the cost optimization web application

1. Open a PowerShell terminal.
2. Change directory to the `3 - Cost Optimization\azd-sample` directory.
3. Run the command `azd down --force --purge --no-prompt`.

You may also log on to the Azure portal, select the resource group and press **Delete Resource group**.  The resource group is named similar to **<USERNAME>-cost-rg**.

### Cleaning up the reliable web app sample

1. Change directory to the `Reference App` directory.
2. Run the command `azd down --force --purge --no-prompt`.

You may also log on to the Azure portal, select each resource group and press **Delete Resource group**.  There are two resource groups: **<USERNAME>-rg** and **<USERNAME>-secondary-rg**.

This process leaves the app registrations used in place. You can clean these up in the Azure Portal.  Go to the Azure Active Directory blade, then **App Registrations** > **Owned applications**.  Remove each app registration associated with your username individually.