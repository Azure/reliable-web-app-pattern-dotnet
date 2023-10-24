using Relecloud.Web.Models.TicketManagement;

namespace Relecloud.Web.Services
{
    public interface ITicketPurchaseService
    {
        Task<PurchaseTicketsResult> PurchaseTicketAsync(PurchaseTicketsRequest request);
    }
}