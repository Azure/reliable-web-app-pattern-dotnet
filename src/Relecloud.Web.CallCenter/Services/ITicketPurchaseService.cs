using Relecloud.Web.Models.TicketManagement;

namespace Relecloud.Web.CallCenter.Services
{
    public interface ITicketPurchaseService
    {
        Task<PurchaseTicketsResult> PurchaseTicketAsync(PurchaseTicketsRequest request);
    }
}