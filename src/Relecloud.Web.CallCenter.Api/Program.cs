// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Microsoft.IdentityModel.Logging;
using Relecloud.Web;
using Relecloud.Web.Api;

var builder = WebApplication.CreateBuilder(args);

var azureCredential = builder.GetAzureTokenCredential();

var hasRequiredConfigSettings = !string.IsNullOrEmpty(builder.Configuration["App:AppConfig:Uri"]);

if (hasRequiredConfigSettings)
{
    builder.Configuration.AddAzureAppConfiguration(options =>
    {
        options
            .Connect(new Uri(builder.Configuration["App:AppConfig:Uri"]), azureCredential)
            .UseFeatureFlags() // Feature flags will be loaded and, by default, refreshed every 30 seconds
            .ConfigureKeyVault(kv =>
            {
                // Some of the values coming from Azure App Configuration are stored Key Vault, use
                // the managed identity of this host for the authentication.
                kv.SetCredential(azureCredential);
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
var startup = new Startup(builder.Configuration, azureCredential);

// Add services to the container.
if (hasRequiredConfigSettings)
{
    startup.ConfigureServices(builder.Services);
}

var hasMicrosoftEntraIdSettings = true;// !string.IsNullOrEmpty(builder.Configuration["Api:MicrosoftEntraId:ClientId"]);

var app = builder.Build();

if (hasRequiredConfigSettings)
{
    startup.Configure(app, app.Environment);
}
else if (!hasMicrosoftEntraIdSettings)
{
    app.MapGet("/", () => "Could not find required Microsoft Entra ID settings. Check your App Config Service, you may need to run the createAppRegistrations script.");
}
else
{
    app.MapGet("/", () => "Could not find required settings. Check your App Service's Configuration section to verify the required settings.");
}

app.Run();
