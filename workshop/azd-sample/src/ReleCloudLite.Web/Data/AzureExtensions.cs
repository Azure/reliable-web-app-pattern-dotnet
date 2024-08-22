using Azure.Core;
using Azure.Identity;

namespace ReleCloudLite.Web.Data;

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
}
