using Azure.Identity;
using Relecloud.Web.Api;
using Microsoft.IdentityModel.Logging;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddAzureAppConfiguration(options =>
{
    options
        .Connect(new Uri(builder.Configuration["Api:AppConfig:Uri"]), new DefaultAzureCredential())
        .ConfigureKeyVault(kv =>
        {
            // In this setup, we must provide Key Vault access to setup
            // App Congiruation even if we do not access Key Vault settings
            kv.SetCredential(new DefaultAzureCredential());
        });
});

// enable developers to override settings with user secrets
builder.Configuration.AddUserSecrets<Program>(optional: true);

builder.Logging.AddConsole();

if (builder.Environment.IsDevelopment())
{
    IdentityModelEventSource.ShowPII = true;
}

// Apps migrating to 6.0 don't need to use the new minimal hosting model
// https://docs.microsoft.com/en-us/aspnet/core/migration/50-to-60?view=aspnetcore-6.0&tabs=visual-studio#apps-migrating-to-60-dont-need-to-use-the-new-minimal-hosting-model
var startup = new Startup(builder.Configuration);

// Add services to the container.
startup.ConfigureServices(builder.Services);

var app = builder.Build();

startup.Configure(app, app.Environment);

app.Run();
