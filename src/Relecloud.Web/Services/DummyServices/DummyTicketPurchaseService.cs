using Relecloud.Web.Models.TicketManagement;

namespace Relecloud.Web.Services.DummyServices
{
    public class DummyTicketPurchaseService : ITicketPurchaseService
    {
        public Task<PurchaseTicketsResult> PurchaseTicketAsync(PurchaseTicketsRequest request)
        {
            return Task.FromResult(new PurchaseTicketsResult
            {
                Status = PurchaseTicketsResultStatus.UnableToProcess
            });
        }
    }
}
