namespace Relecloud.Mocks.PaymentGateway.Models
{
    public class CapturePaymentOptions
    {
        public string HoldCode { get; set; }
        public double AmountToCapture { get; set; }
    }
}
