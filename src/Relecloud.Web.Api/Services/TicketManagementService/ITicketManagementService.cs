using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.TicketManagement;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public interface ITicketManagementService
    {
        TicketManagementServiceProviders GetServiceType();

        Task<CountAvailableTicketsResult> CountAvailableTicketsAsync(int concertId);
        Task<HaveTicketsBeenSoldResult> HaveTicketsBeenSoldAsync(int concertId);

        Task<ReserveTicketsResult> ReserveTicketsAsync(int concertId, string userId, int numberOfTickets);
    }
}
