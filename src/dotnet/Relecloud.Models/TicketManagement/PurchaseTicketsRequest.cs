using Relecloud.Web.Models.TicketManagement.Payment;

namespace Relecloud.Web.Models.TicketManagement
{
    public class PurchaseTicketsRequest
    {
        public string? UserId { get; set; }
        public PaymentDetails? PaymentDetails { get; set; }
        public IDictionary<int, int>? ConcertIdsAndTicketCounts { get; set; }
    }
}
