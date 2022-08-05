using Newtonsoft.Json;
using Newtonsoft.Json.Converters;

namespace Relecloud.Mocks.PaymentGateway.Models
{

    [JsonConverter(typeof(StringEnumConverter))]
    public enum CaptureMethods
    {
        Manual // used when the payment intent is a pre-auth
    }
}
