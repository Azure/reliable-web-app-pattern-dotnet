# 7- Performance Efficiency

Performance efficiency is the ability of a workload to scale and meet the demands placed on it by users in an efficient manner. In cloud environments, a workload should anticipate increases in demand to meet business requirements.

## The Cache-Aside pattern

The Cache-Aside pattern is a technique that's used to manage in-memory data caching. It reduces the request response time and can lead to increased response throughput. This efficiency reduces the number of horizontal scaling events, making the app more capable of handling traffic bursts. It also improves service availability by reducing the load on the primary data store and decreasing the likelihood of service outages.

### Implementing Cache-Aside in Relecloud Lite

### Cache-Aside in Relecloud Concerts
Take a look for the Cache-Aside pattern implementation in our main application.

1. Open the **Relecloud.sln** solution.
1. Note that we use **Microsoft.Extensions.Caching.StackExchangeRedis** for Cacheing.
1. Open the **Startup.cs** of the **Relecloud.Web.CallCenter.Api** project and browse to the `AddDistributedSession` method.
1. Look at the Azure Redis Cache connection string from the configuration settings.

    ```csharp
    var redisCacheConnectionString = Configuration["App:RedisCache:ConnectionString"];
    ```
1. This code uses Azure Redis if the connection string contains a value

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

1. The following code handles if a connection string is not present, use the built-in distributed cache.

    ```csharp
    else
    {
        services.AddDistributedMemoryCache();
    }
    ```

1. Now, we want to cache some of the most used data in our application, and that is getting concerts from the database. Open the **SqlDatabaseConcertRepository.cs** file found in the **Services/SqlDatabaseConcertRepository** folder of the **Relecloud.Web.Api** project.
1. A Private class-level variable holds the distributed cache.

    ```csharp
    private readonly IDistributedCache cache;
    ```

1. The constructor accepts an `IDistributedCache` parameter.

    ```csharp
    public SqlDatabaseConcertRepository(ConcertDataContext database, IDistributedCache cache)
    {
        this.database = database;
        this.cache = cache;
    }
    ```

1. Any time data is modified in the database, the cache needs to be cleared. The `CreateConcertAsync` method includes the cache removal. The method should look like this:

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

1. The same cache clearing to `UpdateConcertAsync`. The method should look like this:

    ```csharp
    public async Task<UpdateResult> UpdateConcertAsync(Concert existingConcert)
    {
        database.Update(existingConcert);
        await database.SaveChangesAsync();

        this.cache.Remove(CacheKeys.UpcomingConcerts);

        return UpdateResult.SuccessResult();
    }
    ```

1. The same thing needs to happen when a concert is deleted. The following code to the `DeleteConcertAsync` method immediately after the `SaveChangesAsync` call:

    ```csharp
    this.cache.Remove(CacheKeys.UpcomingConcerts);
    ```

1. Now, that the cache is cleared when any data modification occurs, we want to put data into the cache when data is read from the database and the cache is empty. Browse to the `GetUpcomingConcertsAsync` method.
1. We'll read from the cache by using `GetStringAsync`. Add the following code immediately under the `IList<Concert>? concerts;` definition.

    ```csharp
    var concertsJson = await this.cache.GetStringAsync(CacheKeys.UpcomingConcerts);
    ```

1. If the returned `concertsJson` has a value, we can deserialize that into the `concerts` variable.

    ```csharp
    if (concertsJson != null)
    {
        concerts = JsonSerializer.Deserialize<IList<Concert>>(concertsJson);
    }
    ```

1. If there is nothing in the `concertsJson` variable, and thus nothing in the cache read the data from the database as normal. Look at the existing data retrieval code inside an else statement:

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

1. Now that we have the data, we want to put it into the cache. Look at the line after the `concerts = await this.database.Concerts.AsNoTracking()` line:

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

## Caching in the Reliable Web App

You should use a single cache instance to support multiple data types rather than using a single instance for each data type.

The reference implementation uses a single Azure Cache for Redis instance to store session state for the front-end web app and the back-end web app. The front-end web app stores two pieces of data in session state. It stores the cart and the Microsoft Authentication Library (MSAL) token.

### Implement Caching in Relecloud Lite

### Caching in Relecloud

1. You can see all of this by using the **Relecloud** solution you already have open.
1. Open the **Relecloud.Web.CallCenter** project.
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

## Next Steps

Thank you for attending this workshop.  We hope you learned something and feel more comfortable tackling the patterns that are used in enterprise web applications. 

[Check how to clean up this workshop in following lesson](../8%20-%20Clean%20Up/README.md). 
