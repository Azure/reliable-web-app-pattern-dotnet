// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure.Core;
using Azure.Storage.Blobs;
using Microsoft.EntityFrameworkCore;
using Microsoft.Identity.Web;
using Microsoft.IdentityModel.Logging;
using Relecloud.Web.Api.Infrastructure;
using Relecloud.Web.Api.Services;
using Relecloud.Web.Api.Services.MockServices;
using Relecloud.Web.Api.Services.Search;
using Relecloud.Web.Api.Services.SqlDatabaseConcertRepository;
using Relecloud.Web.Api.Services.TicketManagementService;
using Relecloud.Web.Models.Services;
using Relecloud.Web.Services.Search;
using System.Diagnostics;

namespace Relecloud.Web.Api
{
    public class Startup
    {
        private readonly TokenCredential _credential;

        public Startup(IConfiguration configuration, TokenCredential credential)
        {
            Configuration = configuration;
            _credential = credential;
        }

        public IConfiguration Configuration { get; }

        public void ConfigureServices(IServiceCollection services)
        {
            // Add services to the container.
            AddMicrosoftEntraIdServices(services);

            services.AddControllers();

            services.AddAzureAppConfiguration();

            // Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
            services.AddEndpointsApiExplorer();
            services.AddSwaggerGen();

            services.AddApplicationInsightsTelemetry(options =>
            {
                options.ConnectionString = Configuration["App:Api:ApplicationInsights:ConnectionString"];
            });

            AddAzureSearchService(services);
            AddConcertContextServices(services);
            AddDistributedSession(services, _credential);
            AddPaymentGatewayService(services);
            AddTicketManagementService(services);
            AddTicketImageService(services);

            // The ApplicationInitializer is injected in the Configure method with all its dependencies and will ensure
            // they are all properly initialized upon construction.
            services.AddScoped<ApplicationInitializer, ApplicationInitializer>();

            services.AddHealthChecks();
        }

        private void AddMicrosoftEntraIdServices(IServiceCollection services)
        {
            // Adds Microsoft Identity platform (AAD v2.0) support to protect this Api
            services.AddMicrosoftIdentityWebApiAuthentication(Configuration, "Api:MicrosoftEntraId");
        }

        private void AddTicketManagementService(IServiceCollection services)
        {
            var sqlDatabaseConnectionString = Configuration["App:SqlDatabase:ConnectionString"];
            if (string.IsNullOrWhiteSpace(sqlDatabaseConnectionString))
            {
                services.AddScoped<ITicketManagementService, MockTicketManagementService>();
                services.AddScoped<ITicketRenderingService, MockTicketRenderingService>();
            }
            else
            {
                services.AddScoped<ITicketManagementService, TicketManagementService>();
                services.AddScoped<ITicketRenderingService, TicketRenderingService>();
            }
        }

        private void AddAzureSearchService(IServiceCollection services)
        {
            var azureSearchServiceName = Configuration["App:AzureSearch:ServiceName"];
            var sqlDatabaseConnectionString = Configuration["App:SqlDatabase:ConnectionString"];
            if (string.IsNullOrWhiteSpace(azureSearchServiceName) && string.IsNullOrWhiteSpace(sqlDatabaseConnectionString))
            {
                // Add a dummy concert search service in case the Azure Search service isn't provisioned and configured yet.
                services.AddScoped<IConcertSearchService, MockConcertSearchService>();
            }
            else if (string.IsNullOrWhiteSpace(azureSearchServiceName))
            {
                services.AddScoped<IConcertSearchService, SqlDatabaseConcertSearchService>();
            }
            else
            {
                // Add a concert search service based on Azure Search.
                services.AddScoped<IConcertSearchService>(x => new AzureSearchConcertSearchService(azureSearchServiceName, sqlDatabaseConnectionString!));
            }
        }

        private void AddConcertContextServices(IServiceCollection services)
        {
            var sqlDatabaseConnectionString = Configuration["App:SqlDatabase:ConnectionString"];

            if (string.IsNullOrWhiteSpace(sqlDatabaseConnectionString))
            {
                services.AddScoped<IConcertRepository, MockConcertRepository>();
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

        private void AddDistributedSession(IServiceCollection services, TokenCredential credential)
        {
            var connectionString = Configuration["App:RedisCache:ConnectionString"];

            if (!string.IsNullOrWhiteSpace(connectionString))
            {
                // If we have a connection string to Redis, use that as the distributed cache.
                // If not, ASP.NET Core automatically injects an in-memory cache.
                services.AddAzureStackExchangeRedisCache(connectionString, credential);
            }
            else
            {
                services.AddDistributedMemoryCache();
            }
        }


        private void AddPaymentGatewayService(IServiceCollection services)
        {
            services.AddScoped<IPaymentGatewayService, MockPaymentGatewayService>();
        }

        private void AddTicketImageService(IServiceCollection services)
        {
            // It is best practice to create Azure SDK clients once and reuse them.
            // https://learn.microsoft.com/azure/storage/blobs/storage-blob-client-management#manage-client-objects
            // https://devblogs.microsoft.com/azure-sdk/lifetime-management-and-thread-safety-guarantees-of-azure-sdk-net-clients/
            services.AddSingleton<ITicketImageService, TicketImageService>();
            var storageAccountUri = Configuration["App:StorageAccount:Uri"]
                ?? throw new InvalidOperationException("Required configuration missing. Could not find App:StorageAccount:Uri setting.");
            services.AddSingleton(sp => new BlobServiceClient(new Uri(storageAccountUri), _credential));
        }

        public void Configure(WebApplication app, IWebHostEnvironment env)
        {
            // Allows refreshing configuration values from Azure App Configuration
            app.UseAzureAppConfiguration();

            // Configure the HTTP request pipeline.
            if (app.Environment.IsDevelopment())
            {
                app.UseSwagger();
                app.UseSwaggerUI();
            }
            using var serviceScope = app.Services.CreateScope();
            serviceScope.ServiceProvider.GetRequiredService<ApplicationInitializer>().Initialize();

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

            app.UseIntermittentErrorRequestMiddleware();

            app.UseHttpsRedirection();

            app.UseAuthentication();
            app.UseAuthorization();

            app.MapHealthChecks("/healthz");

            app.MapGet("/", () => "Default Web API endpoint");
            app.MapControllers();
        }
    }
}
