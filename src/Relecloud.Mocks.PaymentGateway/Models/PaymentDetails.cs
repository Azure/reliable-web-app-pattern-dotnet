using Relecloud.Mocks.PaymentGateway.Models;
using System;

namespace Relecloud.Mocks.PaymentGateway
{
    public class PaymentDetails
    {
        public string NameOnCard { get; set; } = string.Empty;

        public string CardNumber { get; set; } = string.Empty;

        public string SecurityCode { get; set; } = string.Empty;

        public CardTypes CardType { get; set; } = CardTypes.VISA;

        public string ExpirationMonthYear { get; set; } = DateTimeOffset.UtcNow.AddDays(90).ToString("MMyy");
    }
}
