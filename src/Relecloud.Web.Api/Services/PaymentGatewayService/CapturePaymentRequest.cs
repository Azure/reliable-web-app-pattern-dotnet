namespace Relecloud.Web.Api.Services.PaymentGatewayService
{
    public  class CapturePaymentRequest
    {
        public string HoldCode { get; set; } = string.Empty;
        public double TotalPrice { get; set;}
    }
}
