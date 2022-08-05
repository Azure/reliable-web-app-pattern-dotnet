namespace Relecloud.Mocks.PaymentGateway.Models
{
    public class CapturePaymentResult
    {
        public CapturePaymentStatuses Status { get; set; }
        public string ConfirmationNumber { get; set; }
    }
}
