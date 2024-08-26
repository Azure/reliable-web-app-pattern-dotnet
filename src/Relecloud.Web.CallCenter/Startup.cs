// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure.Core;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.TokenCacheProviders.Distributed;
using Microsoft.Identity.Web.UI;
using Microsoft.IdentityModel.Logging;
using Microsoft.Net.Http.Headers;
using Polly;
using Polly.Contrib.WaitAndRetry;
using Polly.Extensions.Http;
using Relecloud.Web.CallCenter.Infrastructure;
using Relecloud.Web.CallCenter.Services;
using Relecloud.Web.CallCenter.Services.ApiConcertService;
using Relecloud.Web.CallCenter.Services.MockServices;
using Relecloud.Web.CallCenter.Services.RelecloudApiServices;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Services;
using System.Diagnostics;

namespace Relecloud.Web
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
            services.AddHttpContextAccessor();
            services.Configure<RelecloudApiOptions>(Configuration.GetSection("App:RelecloudApi"));
            services.AddOptions();
            AddMicrosoftEntraIdServices(services);
            services.AddControllersWithViews();
            services.AddApplicationInsightsTelemetry(options =>
            {
                options.ConnectionString = Configuration["App:Api:ApplicationInsights:ConnectionString"];
            });

            AddConcertContextService(services);
            AddConcertSearchService(services);
            AddTicketPurchaseService(services);
            AddTicketImageService(services);
            AddAzureCacheForRedis(services);
            services.AddHealthChecks();

            // Add support for session state.
            // NOTE: If there is a distibuted cache service (e.g. Redis) then this will be used to store session data.
            services.AddSession();
        }

        private void AddAzureCacheForRedis(IServiceCollection services)
        {
            var connectionString = Configuration["App:RedisCache:ConnectionString"];

            if (!string.IsNullOrWhiteSpace(connectionString))
            {
                services.AddAzureStackExchangeRedisCache(connectionString, _credential);
            }
            else
            {
                services.AddDistributedMemoryCache();
            }
        }

        private void AddTicketPurchaseService(IServiceCollection services)
        {
            var baseUri = Configuration["App:RelecloudApi:BaseUri"];
            if (string.IsNullOrWhiteSpace(baseUri))
            {
                services.AddScoped<ITicketPurchaseService, MockTicketPurchaseService>();
            }
            else
            {
                services.AddHttpClient<ITicketPurchaseService, RelecloudApiTicketPurchaseService>(httpClient =>
                {
                    httpClient.BaseAddress = new Uri(baseUri);
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.Accept, "application/json");
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.UserAgent, "Relecloud.Web.CallCenter");
                })
                .AddPolicyHandler(GetRetryPolicy())
                .AddPolicyHandler(GetCircuitBreakerPolicy());
            }
        }

        private void AddConcertSearchService(IServiceCollection services)
        {
            var baseUri = Configuration["App:RelecloudApi:BaseUri"];
            if (string.IsNullOrWhiteSpace(baseUri))
            {
                services.AddScoped<IConcertSearchService, MockConcertSearchService>();
            }
            else
            {
                services.AddHttpClient<IConcertSearchService, RelecloudApiConcertSearchService>(httpClient =>
                {
                    httpClient.BaseAddress = new Uri(baseUri);
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.Accept, "application/json");
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.UserAgent, "Relecloud.Web.CallCenter");
                })
                .AddPolicyHandler(GetRetryPolicy())
                .AddPolicyHandler(GetCircuitBreakerPolicy());
            }
        }

        private void AddTicketImageService(IServiceCollection services)
        {
            var baseUri = Configuration["App:RelecloudApi:BaseUri"];
            if (string.IsNullOrWhiteSpace(baseUri))
            {
                services.AddScoped<ITicketImageService, MockTicketImageService>();
            }
            else
            {
                services.AddHttpClient<ITicketImageService, RelecloudApiTicketImageService>(httpClient =>
                {
                    httpClient.BaseAddress = new Uri(baseUri);
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.Accept, "application/octet-stream");
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.UserAgent, "Relecloud.Web.CallCenter");
                })
                .AddPolicyHandler(GetRetryPolicy())
                .AddPolicyHandler(GetCircuitBreakerPolicy());
            }
        }

        private static IAsyncPolicy<HttpResponseMessage> GetRetryPolicy()
        {
            var delay = Backoff.DecorrelatedJitterBackoffV2(TimeSpan.FromMilliseconds(500), retryCount: 3);

            return HttpPolicyExtensions
              .HandleTransientHttpError()
              .WaitAndRetryAsync(delay);
        }

        private static IAsyncPolicy<HttpResponseMessage> GetCircuitBreakerPolicy()
        {
            return HttpPolicyExtensions
                .HandleTransientHttpError()
                .OrResult(msg => msg.StatusCode == System.Net.HttpStatusCode.NotFound)
                .CircuitBreakerAsync(5, TimeSpan.FromSeconds(30));
        }

        private void AddConcertContextService(IServiceCollection services)
        {
            var baseUri = Configuration["App:RelecloudApi:BaseUri"];
            if (string.IsNullOrWhiteSpace(baseUri))
            {
                services.AddScoped<IConcertContextService, MockConcertContextService>();
            }
            else
            {
                services.AddHttpClient<IConcertContextService, RelecloudApiConcertService>(httpClient =>
                {
                    httpClient.BaseAddress = new Uri(baseUri);
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.Accept, "application/json");
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.UserAgent, "Relecloud.Web");
                })
                .AddPolicyHandler(GetRetryPolicy())
                .AddPolicyHandler(GetCircuitBreakerPolicy());
            }
        }

        private void AddMicrosoftEntraIdServices(IServiceCollection services)
        {
            services.AddRazorPages().AddMicrosoftIdentityUI();

            services.AddAuthorization(options =>
            {
                options.AddPolicy(Roles.Administrator, authBuilder =>
                {
                    authBuilder.RequireRole(Roles.Administrator);
                });
            });

            var builder = services.AddMicrosoftIdentityWebAppAuthentication(Configuration, "MicrosoftEntraId")
                .EnableTokenAcquisitionToCallDownstreamApi(new string[] { })
                .AddDownstreamApi("relecloud-api", Configuration.GetSection("GraphBeta"));

            // when using Microsoft.Identity.Web to retrieve an access token on behalf of the authenticated user
            // you should use a shared session state provider.
            // https://learn.microsoft.com/en-us/azure/active-directory-b2c/configure-authentication-sample-web-app-with-api?tabs=visual-studio#token-cache-for-a-web-app
            if (string.IsNullOrEmpty(Configuration["App:RedisCache:ConnectionString"]))
            {
                builder.AddInMemoryTokenCaches();
            }
            else
            {
                builder.AddDistributedTokenCaches();
                services.Configure<MsalDistributedTokenCacheAdapterOptions>(options =>
                {
                    options.DisableL1Cache = true;
                });
            }

            services.Configure<OpenIdConnectOptions>(Configuration.GetSection("MicrosoftEntraId"));
            if (!Debugger.IsAttached)
            {
                // this sample uses AFD for the URL registered with Microsoft Entra ID to make it easier to get started
                // but we recommend host name preservation for production scenarios
                // https://learn.microsoft.com/en-us/azure/architecture/best-practices/host-name-preservation
                services.Configure<ForwardedHeadersOptions>(options =>
                {
                    // not needed when using host name preservation
                    options.ForwardedHeaders = ForwardedHeaders.XForwardedHost | ForwardedHeaders.XForwardedProto;
                });

                services.Configure((Action<MicrosoftIdentityOptions>)(options =>
                {
                    var frontDoorHostname = Configuration["App:FrontDoorHostname"];
                    var callbackPath = Configuration["MicrosoftEntraId:CallbackPath"];

                    options.Events.OnTokenValidated += async ctx =>
                    {
                        await CreateOrUpdateUserInformation(ctx);
                    };
                    options.Events.OnRedirectToIdentityProvider += ctx =>
                    {
                        // not needed when using host name preservation
                        ctx.ProtocolMessage.RedirectUri = $"https://{frontDoorHostname}{callbackPath}";
                        return Task.CompletedTask;
                    };
                    options.Events.OnRedirectToIdentityProviderForSignOut += ctx =>
                    {
                        // not needed when using host name preservation
                        ctx.ProtocolMessage.PostLogoutRedirectUri = $"https://{frontDoorHostname}";
                        return Task.CompletedTask;
                    };
                }));
            }
        }

        private static async Task CreateOrUpdateUserInformation(TokenValidatedContext ctx)
        {
            try
            {
                if (ctx.Principal?.Identity is not null)
                {
                    // The user has signed in, ensure the information in the database is up-to-date.
                    var user = new User
                    {
                        Id = ctx.Principal.GetUniqueId(),
                        DisplayName = ctx.Principal.Identity.Name ?? "New User"
                    };

                    var concertService = ctx.HttpContext.RequestServices.GetRequiredService<IConcertContextService>();
                    await concertService.CreateOrUpdateUserAsync(user);
                }
            }
            catch (Exception ex)
            {
                var logger = ctx.HttpContext.RequestServices.GetRequiredService<ILogger<Startup>>();
                logger.LogError(ex, "Unhandled exception from Startup.CreateOrUpdateUserInformation");
            }
        }

        public void Configure(WebApplication app, IWebHostEnvironment env)
        {
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

            // this sample uses AFD for the URL registered with Microsoft Entra ID to make it easier to get started
            // but we recommend host name preservation for production scenarios
            // https://learn.microsoft.com/en-us/azure/architecture/best-practices/host-name-preservation
            app.UseForwardedHeaders();

            app.UseHttpsRedirection();
            app.UseStaticFiles();

            app.UseRouting();

            app.UseAuthentication();
            app.UseAuthorization();

            app.UseSession(); // required for carts

            app.MapHealthChecks("/healthz");

            app.MapControllerRoute(
                name: "default",
                pattern: "{controller=Home}/{action=Index}/{id?}");
            app.MapRazorPages();
        }
    }
}
