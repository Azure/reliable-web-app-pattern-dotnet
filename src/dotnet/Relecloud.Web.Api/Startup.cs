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
            AddConcertContextServices(services);
            AddDistributedSession(services);
            AddPaymentGatewayService(services);
            AddTicketManagementService(services);
            AddTicketImageService(services);
            services.AddHealthChecks();

            // The ApplicationInitializer is injected in the Configure method with all its dependencies and will ensure
            // they are all properly initialized upon construction.
            services.AddScoped<ApplicationInitializer, ApplicationInitializer>();
        }

        private void AddAzureAdServices(IServiceCollection services)
        {
            // Adds Microsoft Identity platform (AAD v2.0) support to protect this Api
            services.AddMicrosoftIdentityWebApiAuthentication(Configuration, "Api:AzureAd");
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


        private void AddTicketImageService(IServiceCollection services)
        {
            services.AddScoped<ITicketImageService, TicketImageService>();
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
                services.AddScoped<IConcertSearchService>(x => new AzureSearchConcertSearchService(azureSearchServiceName, sqlDatabaseConnectionString));
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
            services.AddScoped<IPaymentGatewayService, MockPaymentGatewayService>();
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

            app.UseRetryTestingMiddleware();

            app.UseHttpsRedirection();

            app.UseAuthentication();
            app.UseAuthorization();

            app.MapControllers();
            app.MapHealthChecks("/healthz");
        }
    }
}
