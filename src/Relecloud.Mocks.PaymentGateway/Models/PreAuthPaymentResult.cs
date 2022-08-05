namespace Relecloud.Mocks.PaymentGateway.Models
{
    public class PreAuthPaymentResult
    {
        public PreAuthPaymentStatuses Status { get; set; }
        public string HoldCode { get; set; }
    }
}
