using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.TokenCacheProviders.Distributed;
using Microsoft.Identity.Web.UI;
using Microsoft.IdentityModel.Logging;
using Microsoft.Net.Http.Headers;
using Polly;
using Polly.Contrib.WaitAndRetry;
using Polly.Extensions.Http;
using Relecloud.Web.Infrastructure;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Services;
using Relecloud.Web.Services;
using Relecloud.Web.Services.ApiConcertService;
using Relecloud.Web.Services.MockServices;
using Relecloud.Web.Services.RelecloudApiServices;
using System.Diagnostics;
using System.Security.Claims;

namespace Relecloud.Web
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
            services.AddHttpContextAccessor();
            services.Configure<RelecloudApiOptions>(Configuration.GetSection("App:RelecloudApi"));
            services.AddOptions();
            AddAzureAdServices(services);
            services.AddControllersWithViews();
            services.AddApplicationInsightsTelemetry(Configuration["App:Api:ApplicationInsights:ConnectionString"]);

            AddConcertContextService(services);
            AddConcertSearchService(services);
            AddTicketPurchaseService(services);
            AddAzureCacheForRedis(services);

            // Add support for session state.
            // NOTE: If there is a distibuted cache service (e.g. Redis) then this will be used to store session data.
            services.AddSession();
        }

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
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.UserAgent, "Relecloud.Web");
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
                    httpClient.DefaultRequestHeaders.Add(HeaderNames.UserAgent, "Relecloud.Web");
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
            string baseUri = Configuration["App:RelecloudApi:BaseUri"];
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

        private void AddAzureAdServices(IServiceCollection services)
        {
            services.AddRazorPages().AddMicrosoftIdentityUI();
            
            services.AddAuthorization(options =>
            {
                options.AddPolicy(Roles.Administrator, authBuilder =>
                {
                    authBuilder.RequireRole(Roles.Administrator);
                });
            });

            var builder = services.AddMicrosoftIdentityWebAppAuthentication(Configuration, "AzureAd")
            .EnableTokenAcquisitionToCallDownstreamApi(new string[] { })
               .AddDownstreamWebApi("relecloud-api", Configuration.GetSection("GraphBeta"));

            // when using Microsoft.Identity.Web to retrieve an access token on behalf of the authenticated user
            // you should use a shared session state provider.
            // https://docs.microsoft.com/en-us/azure/active-directory-b2c/configure-authentication-sample-web-app-with-api?tabs=visual-studio#token-cache-for-a-web-app
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

            services.Configure<OpenIdConnectOptions>(Configuration.GetSection("AzureAd"));
            services.Configure((Action<MicrosoftIdentityOptions>)(options =>
            {
                options.Events = new OpenIdConnectEvents
                {
                    OnTokenValidated = async ctx =>
                    {
                        TransformRoleClaims(ctx);
                        await CreateOrUpdateUserInformation(ctx);   
                    }
                };
            }));
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
                logger.LogError(ex, "Unhandled exception from Startup.TransformRoleClaims");
            }
        }

        private static void TransformRoleClaims(TokenValidatedContext ctx)
        {
            try
            {
                const string RoleClaim = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role";
                if (ctx.Principal?.Identity is not null)
                {
                    // Find all claims of the requested claim type, split their values by spaces
                    // and then take the ones that aren't yet on the principal individually.
                    var claims = ctx.Principal.FindAll("extension_AppRoles")
                    .SelectMany(c => c.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries))
                    .Where(s => !ctx.Principal.HasClaim(RoleClaim, s)).ToList();

                    // Add all new claims to the principal's identity.
                    ((ClaimsIdentity)ctx.Principal.Identity).AddClaims(claims.Select(s => new Claim(RoleClaim, s)));
                }
            }
            catch (Exception ex)
            {
                var logger = ctx.HttpContext.RequestServices.GetRequiredService<ILogger<Startup>>();
                logger.LogError(ex, "Unhandled exception from Startup.TransformRoleClaims");
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

            app.UseHttpsRedirection();
            app.UseStaticFiles();

            app.UseRouting();

            app.UseAuthentication();
            app.UseAuthorization();

            app.UseSession(); // required for carts

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllerRoute(
                    name: "default",
                    pattern: "{controller=Home}/{action=Index}/{id?}");
                endpoints.MapRazorPages();
            });
        }
    }
}
