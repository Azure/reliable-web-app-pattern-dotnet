namespace Relecloud.Mocks.PaymentGateway.Models
{
    public class PaymentOptions
    {
        public PaymentOptions(CaptureMethods captureMethod)
        {
            CaptureMethod = captureMethod;
        }

        internal CaptureMethods CaptureMethod { get; private set; }

        public double Amount {get;set;}
        public CurrencyTypes Currency { get; set; }
        public PaymentDetails PaymentDetails { get; set; }
        public Order Order { get; set; }
    }
}
