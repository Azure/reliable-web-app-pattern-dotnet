using System.Text.Json;

namespace Relecloud.Web.CallCenter.Infrastructure
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
