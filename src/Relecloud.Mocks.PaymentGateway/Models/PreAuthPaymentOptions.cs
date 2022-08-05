namespace Relecloud.Mocks.PaymentGateway.Models
{
    public class PreAuthPaymentOptions : PaymentOptions
    {
        public PreAuthPaymentOptions() : base(CaptureMethods.Manual) { }
    }
}
