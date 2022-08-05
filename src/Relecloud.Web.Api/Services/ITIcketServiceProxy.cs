using Relecloud.Web.Api.Services.TicketManagementService;
using Relecloud.Web.Models.TicketManagement;

namespace Relecloud.Web.Api.Services
{
    public interface ITIcketServiceProxy
    {
        Task<CountAvailableTicketsResult> CountAvailableTicketsAsync(int concertId);
        Task<HaveTicketsBeenSoldResult> HaveTicketsBeenSoldAsync(int concertId);
        Task<ReserveTicketsResult> ReserveTicketsAsync(IDictionary<int, int> concertIdsAndTicketCounts, string userId);
    }
}
