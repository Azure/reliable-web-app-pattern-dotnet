using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.Identity.Web;
using Microsoft.IdentityModel.Logging;
using Polly;
using Polly.Contrib.WaitAndRetry;
using Polly.Extensions.Http;
using Relecloud.Web.Api.Infrastructure;
using Relecloud.Web.Api.Services;
using Relecloud.Web.Api.Services.DummyServices;
using Relecloud.Web.Api.Services.PaymentGatewayService;
using Relecloud.Web.Api.Services.SqlDatabaseConcertRepository;
using Relecloud.Web.Api.Services.StorageAccountEventSenderService;
using Relecloud.Web.Api.Services.TicketManagementService;
using Relecloud.Web.Models.Services;
using Relecloud.Web.Services.AzureSearchService;
using Relecloud.Web.Services.PaymentGatewayService;
using System.Diagnostics;

namespace Relecloud.Web.Api
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }
        public void ConfigureServices(IServiceCollection services)
        {
            // Add services to the container.
            AddAzureAdServices(services);

            services.AddControllers();

            // Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
            services.AddEndpointsApiExplorer();
            services.AddSwaggerGen();

            services.AddApplicationInsightsTelemetry(Configuration["App:Api:ApplicationInsights:ConnectionString"]);

            AddAzureSearchService(services);
            AddConcerContextServices(services);
            AddDistributedSession(services);
            AddPaymentGatewayService(services);
            AddEventSenderService(services);
            AddTicketManagementService(services);

            // The ApplicationInitializer is injected in the Configure method with all its dependencies and will ensure
            // they are all properly initialized upon construction.
            services.AddScoped<ApplicationInitializer, ApplicationInitializer>();
        }

        private void AddAzureAdServices(IServiceCollection services)
        {
            // Adds Microsoft Identity platform (AAD v2.0) support to protect this Api
            services.AddMicrosoftIdentityWebApiAuthentication(Configuration, "Api:AzureAd");
        }

        private static IAsyncPolicy<HttpResponseMessage> GetRetryPolicy()
        {
            var delay = Backoff.DecorrelatedJitterBackoffV2(TimeSpan.FromMilliseconds(500), retryCount: 3);

            return HttpPolicyExtensions
              .HandleTransientHttpError()
              .OrResult(msg => msg.StatusCode == System.Net.HttpStatusCode.NotFound)
              .WaitAndRetryAsync(delay);
        }

        private static IAsyncPolicy<HttpResponseMessage> GetCircuitBreakerPolicy()
        {
            return HttpPolicyExtensions
                .HandleTransientHttpError()
                .CircuitBreakerAsync(5, TimeSpan.FromSeconds(30));
        }

        private void AddTicketManagementService(IServiceCollection services)
        {
            services.AddScoped<ITIcketServiceProxy, TicketServiceProxy>();

            var section = Configuration.GetSection("App:TicketManagement");
            services.Configure<TicketManagementServiceOptions>(section);
            var options = section.Get<TicketManagementServiceOptions>();

            if (options is null || string.IsNullOrEmpty(options.BaseUri) || string.IsNullOrEmpty(options.ApiKey))
            {
                services.AddScoped<ITicketManagementService, DummyTicketManagementService>();
                services.AddScoped<ITicketServiceFactory, DummyTicketServiceFactory>();
            }
            else
            {
                services.AddTransient(context => new MockTicketServiceAuthenticationHandler(options.ApiKey));
                services.AddHttpClient<ITicketManagementService, MockTicketManagementServiceFacade>()
                    .AddHttpMessageHandler<MockTicketServiceAuthenticationHandler>()
                    .AddPolicyHandler(GetRetryPolicy())
                    .AddPolicyHandler(GetCircuitBreakerPolicy());

                services.AddScoped<ITicketManagementService, SqlTicketManagementService>();
                services.AddScoped<ITicketServiceFactory, TicketServiceFactory>();
            }

        }

        private void AddAzureSearchService(IServiceCollection services)
        {
            var azureSearchServiceName = Configuration["App:AzureSearch:ServiceName"];
            var sqlDatabaseConnectionString = Configuration["App:SqlDatabase:ConnectionString"];
            if (string.IsNullOrWhiteSpace(azureSearchServiceName) && string.IsNullOrWhiteSpace(sqlDatabaseConnectionString))
            {
                // Add a dummy concert search service in case the Azure Search service isn't provisioned and configured yet.
                services.AddScoped<IConcertSearchService, DummyConcertSearchService>();
            }
            else if (string.IsNullOrWhiteSpace(azureSearchServiceName))
            {
                services.AddScoped<IConcertSearchService, SqlDatabaseConcertSearchService>();
            }
            else
            {
                // Add a concert search service based on Azure Search.
                services.AddScoped<IConcertSearchService>(x => new AzureSearchConcertSearchService(azureSearchServiceName, sqlDatabaseConnectionString));
            }
        }

        private void AddEventSenderService(IServiceCollection services)
        {
            var storageAccountConnectionString = Configuration["App:StorageAccount:QueueConnectionString__queueServiceUri"];
            var storageAccountEventQueueName = Configuration["App:StorageAccount:EventQueueName"];
            if (string.IsNullOrWhiteSpace(storageAccountConnectionString) || string.IsNullOrWhiteSpace(storageAccountEventQueueName))
            {
                // Add a dummy event sender service in case the Azure Storage account isn't provisioned and configured yet.
                services.AddScoped<IAzureEventSenderService, DummyEventSenderService>();
            }
            else
            {
                // Add an event sender service based on Azure Storage.
                services.AddScoped<IAzureEventSenderService>(x => new StorageAccountEventSenderService(storageAccountConnectionString, storageAccountEventQueueName));
            }
        }

        private void AddConcerContextServices(IServiceCollection services)
        {
            services.AddSingleton<ITicketNumberGenerator, TicketNumberGenerator>();

            var sqlDatabaseConnectionString = Configuration["App:SqlDatabase:ConnectionString"];

            if (string.IsNullOrWhiteSpace(sqlDatabaseConnectionString))
            {
                services.AddScoped<IConcertRepository, DummyConcertRepository>();
            }
            else
            {
                // Add a concert repository based on Azure SQL Database.
                services.AddDbContextPool<ConcertDataContext>(options => options.UseSqlServer(sqlDatabaseConnectionString,
                    sqlServerOptionsAction: sqlOptions =>
                    {
                        sqlOptions.EnableRetryOnFailure(
                        maxRetryCount: 5,
                        maxRetryDelay: TimeSpan.FromSeconds(3),
                        errorNumbersToAdd: null);
                    }));
                services.AddScoped<IConcertRepository, SqlDatabaseConcertRepository>();
            }
        }

        private void AddDistributedSession(IServiceCollection services)
        {
            var redisCacheConnectionString = Configuration["App:RedisCache:ConnectionString"];
            if (!string.IsNullOrWhiteSpace(redisCacheConnectionString))
            {
                // If we have a connection string to Redis, use that as the distributed cache.
                // If not, ASP.NET Core automatically injects an in-memory cache.
                services.AddStackExchangeRedisCache(options =>
                {
                    options.Configuration = redisCacheConnectionString;
                });
            }
            else
            {
                services.AddDistributedMemoryCache();
            }
        }

        private void AddPaymentGatewayService(IServiceCollection services)
        {
            var section = Configuration.GetSection("App:Payment");
            services.Configure<PaymentGatewayOptions>(section);
            var options = section.Get<PaymentGatewayOptions>();

            if (options is null || string.IsNullOrWhiteSpace(options.BaseUri)|| string.IsNullOrWhiteSpace(options.ApiKey))
            {
                services.AddScoped<IPaymentGatewayService, DummyPaymentGatewayService>();
            }
            else
            {
                services.AddTransient(context => new MockPaymentGatewayAuthenticationHandler(options.ApiKey));
                services.AddHttpClient<IPaymentGatewayService, MockPaymentGatewayServiceFacade>()
                    .AddHttpMessageHandler<MockPaymentGatewayAuthenticationHandler>()
                    .AddPolicyHandler(GetRetryPolicy())
                    .AddPolicyHandler(GetCircuitBreakerPolicy());
            }
        }

        public void Configure(WebApplication app, IWebHostEnvironment env)
        {
            // Configure the HTTP request pipeline.
            if (app.Environment.IsDevelopment())
            {
                app.UseSwagger();
                app.UseSwaggerUI();
            }
            using var serviceScope = app.Services.CreateScope();
            serviceScope.ServiceProvider.GetService<ApplicationInitializer>()!.Initialize();

            // Configure the HTTP request pipeline.
            if (!env.IsDevelopment())
            {
                app.UseExceptionHandler("/Home/Error");
                // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
                app.UseHsts();
            }
            else if (Debugger.IsAttached)
            {
                // By default, we do not include any potential PII (personally identifiable information) in our exceptions in order to be in compliance with GDPR.
                // https://aka.ms/IdentityModel/PII
                IdentityModelEventSource.ShowPII = true;
            }

            app.UseRoleClaimsMiddleware();

            app.UseHttpsRedirection();

            app.UseAuthentication();
            app.UseAuthorization();

            app.MapControllers();
        }
    }
}
