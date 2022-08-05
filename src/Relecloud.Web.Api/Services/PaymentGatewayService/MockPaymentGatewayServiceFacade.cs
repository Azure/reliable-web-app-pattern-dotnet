using Microsoft.Extensions.Options;
using Relecloud.Web.Models.Services;
using ServiceProviders.Payment;

namespace Relecloud.Web.Api.Services.PaymentGatewayService
{
    public class MockPaymentGatewayServiceFacade : IPaymentGatewayService
    {
        private readonly MockPaymentGateway paymentGateway;
        private readonly IConcertRepository concertContextService;

        public MockPaymentGatewayServiceFacade(HttpClient client, IConcertRepository concertRepository, IOptions<PaymentGatewayOptions> options)
        {
            this.paymentGateway = new MockPaymentGateway(client);
            if (!string.IsNullOrEmpty(options?.Value?.BaseUri))
            {
                this.paymentGateway.BaseUrl = options.Value.BaseUri;
            }
            this.concertContextService = concertRepository;
        }

        public async Task<CapturePaymentResult> CapturePaymentAsync(CapturePaymentRequest request)
        {
            var captureOptions = new CapturePaymentOptions
            {
                AmountToCapture = (double)request.TotalPrice,
                HoldCode = request.HoldCode
            };

            var gatewayResponse = await paymentGateway.CapturePaymentAsync(captureOptions);

            return new CapturePaymentResult
            {
                Status = gatewayResponse.Status == null ? CapturePaymentResultStatus.InvalidHoldCode: (CapturePaymentResultStatus)gatewayResponse.Status,
                ConfirmationNumber = gatewayResponse.ConfirmationNumber
            };
        }

        public async Task<PreAuthPaymentResult> PreAuthPaymentAsync(PreAuthPaymentRequest request)
        {
            if (request.Tickets == null)
            {
                throw new ArgumentNullException("Expected to receive tickets for purchase");
            }
            if (request.PaymentDetails == null)
            {
                throw new ArgumentNullException("Expected to receive payment details for purchase");
            }

            var concerts = await concertContextService.GetConcertsByIdAsync(request.Tickets.Keys);
            var preAuthOptions = new PreAuthPaymentOptions
            {
                Amount = Convert.ToDouble(request.Amount),
                PaymentDetails = new PaymentDetails
                {
                    CardNumber = request.PaymentDetails.CardNumber,
                    CardType = PaymentDetailsCardType.Visa,
                    ExpirationMonthYear = request.PaymentDetails.ExpirationMonthYear,
                    NameOnCard = request.PaymentDetails.NameOnCard,
                    SecurityCode = request.PaymentDetails.SecurityCode,
                },
                Order = new Order
                {
                    Items = new List<OrderItem>()
                }
            };
              
            foreach(var concertId in request.Tickets.Keys)
            {
                var firstConcert = concerts.First(concert => concert.Id == concertId);
                preAuthOptions.Order.Items.Add(new OrderItem()
                {

                    Name = firstConcert.Title,
                    Price = (double)firstConcert.Price * request.Tickets[concertId],
                    Quantity = request.Tickets[concertId],
                    Sku = concertId.ToString()
                });
            }

            // returns the hold code that must be sent when invoking capture
            var gatewayResponse = await paymentGateway.PreAuthPaymentAsync(preAuthOptions);

            return new PreAuthPaymentResult
            {
                HoldCode = gatewayResponse.HoldCode,
                Status = gatewayResponse.Status== null ? default(PreAuthPaymentResultStatus) : (PreAuthPaymentResultStatus)(gatewayResponse.Status),
            };
        }
    }
}
