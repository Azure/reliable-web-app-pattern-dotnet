using Newtonsoft.Json;
using Newtonsoft.Json.Converters;

namespace Relecloud.Mocks.PaymentGateway.Models
{
    [JsonConverter(typeof(StringEnumConverter))]
    public enum CapturePaymentStatuses
    {
        CaptureSuccessful,
        InvalidHoldCode,
        InvalidHoldAmount
    }
}
