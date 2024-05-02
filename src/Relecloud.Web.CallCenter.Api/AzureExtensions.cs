using Azure.Core;
using Azure.Identity;
using StackExchange.Redis;
using System.IdentityModel.Tokens.Jwt;

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

        public static void AddAzureStackExchangeRedisCache(this IServiceCollection services, string redisCacheName, TokenCredential token)
        {
            // We prefer not to get async results this way, but there's no easy way to handle this at the moment
            var configurationOptions = ConfigureAzureRedisAsync(redisCacheName, token).GetAwaiter().GetResult();

            services.AddStackExchangeRedisCache(options =>
            {
                options.ConfigurationOptions = configurationOptions;
            });
        }

        /// <summary>
        /// Connects Azure Redis to use managed identiy.
        /// </summary>
        /// <remarks>
        /// Currently, the service requires the name of the identity which is also the object id of the identity. We can retrieve it from the supplied credential so we do that here.
        /// For the current discussion on this, see https://github.com/Azure/Microsoft.Azure.StackExchangeRedis/issues/17
        /// </remarks>
        private static async Task<ConfigurationOptions> ConfigureAzureRedisAsync(string connectionString, TokenCredential credential)
        {
            var options = ConfigurationOptions.Parse(connectionString);

            // Use a placeholder principalId before we can extract
            await options.ConfigureForAzureAsync(new() { PrincipalId = string.Empty, TokenCredential = credential });

            // Extract actual principal id
            var jwt = options.Defaults.Password;
            var handler = new JwtSecurityTokenHandler();
            var token = handler.ReadJwtToken(jwt);
            var clientid = token.Payload["oid"].ToString();

            options.User = clientid;

            return options;
        }
    }
}
