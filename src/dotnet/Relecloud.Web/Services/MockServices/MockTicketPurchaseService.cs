using Relecloud.Web.Models.TicketManagement;

namespace Relecloud.Web.Services.MockServices
{
    public class MockTicketPurchaseService : ITicketPurchaseService
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
