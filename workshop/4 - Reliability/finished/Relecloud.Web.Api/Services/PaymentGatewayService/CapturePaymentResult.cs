using Relecloud.Web.Models.Services;

namespace Relecloud.Web.Api.Services.PaymentGatewayService
{
    public class CapturePaymentResult : IServiceProviderResult
    {
        public CapturePaymentResultStatus Status { get; set; }
        public string ConfirmationNumber { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
    }
}
