using Azure.Core;
using Azure.Identity;
using StackExchange.Redis;

namespace Relecloud.Web
{
    internal static class AzureExtensions
    {
        public static TokenCredential GetAzureTokenCredential(this WebApplicationBuilder builder) => builder.Configuration["App:AzureCredentialType"] switch
        {
            "AzureCLI" => new AzureCliCredential(),
            "Environment" => new EnvironmentCredential(),
            "ManagedIdentity" => new ManagedIdentityCredential(builder.Configuration["AZURE_CLIENT_ID"]),
            "VisualStudio" => new VisualStudioCredential(),
            "VisualStudioCode" => new VisualStudioCodeCredential(),
            _ => new DefaultAzureCredential(new DefaultAzureCredentialOptions { ManagedIdentityClientId = builder.Configuration["AZURE_CLIENT_ID"] }),
        };

        public static void AddAzureStackExchangeRedisCache(this IServiceCollection services, string connectionString, TokenCredential credential)
        {
            var configurationOptions = ConfigurationOptions.Parse(connectionString);

            // We prefer not to get async results this way, but there's no easy way to handle this at the moment
            configurationOptions.ConfigureForAzureWithTokenCredentialAsync(credential).GetAwaiter().GetResult();

            services.AddStackExchangeRedisCache(options =>
            {
                options.ConfigurationOptions = configurationOptions;
            });
        }
    }
}
