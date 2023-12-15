using Azure.Identity;
using Microsoft.IdentityModel.Logging;
using Relecloud.Web.Api;

var builder = WebApplication.CreateBuilder(args);

var hasRequiredConfigSettings = !string.IsNullOrEmpty(builder.Configuration["App:AppConfig:Uri"]);

if (hasRequiredConfigSettings)
{
    builder.Configuration.AddAzureAppConfiguration(options =>
    {
        options
            .Connect(new Uri(builder.Configuration["App:AppConfig:Uri"]), new DefaultAzureCredential())
            .ConfigureKeyVault(kv =>
            {
                // Some of the values coming from Azure App Configuration are stored Key Vault, use
                // the managed identity of this host for the authentication.
                kv.SetCredential(new DefaultAzureCredential());
            });
    });
}

// enable developers to override settings with user secrets
builder.Configuration.AddUserSecrets<Program>(optional: true);

builder.Logging.AddConsole();

if (builder.Environment.IsDevelopment())
{
    IdentityModelEventSource.ShowPII = true;
}

// Apps migrating to 6.0 don't need to use the new minimal hosting model
// https://learn.microsoft.com/en-us/aspnet/core/migration/50-to-60?view=aspnetcore-6.0&tabs=visual-studio#apps-migrating-to-60-dont-need-to-use-the-new-minimal-hosting-model
var startup = new Startup(builder.Configuration);

// Add services to the container.
if (hasRequiredConfigSettings)
{
    startup.ConfigureServices(builder.Services);
}

var hasAzureAdSettings = !string.IsNullOrEmpty(builder.Configuration["Api:AzureAd:ClientId"]);

var app = builder.Build();

if (hasRequiredConfigSettings)
{
    startup.Configure(app, app.Environment);
}
else if (!hasAzureAdSettings)
{
    app.MapGet("/", () => "Could not find required Azure AD settings. Check your App Config Service, you may need to run the createAppRegistrations script.");
}
else
{
    app.MapGet("/", () => "Could not find required settings. Check your App Service's Configuration section to verify the required settings.");
}

app.Run();
