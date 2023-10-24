using System.Text.Json;

namespace Relecloud.Web.Infrastructure
{
    public class RelecloudApiConfiguration
    {
        public static JsonSerializerOptions GetSerializerOptions()
        {
            return new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            };
        }
    }
}
