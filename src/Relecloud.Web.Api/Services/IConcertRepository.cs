using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Services;

namespace Relecloud.Web.Api.Services
{
    public interface IConcertRepository : IConcertContextService
    {
        public void Initialize();
        Task<UpdateResult> CreateOrUpdateTicketNumbersAsync(int concertId, int numberOfTickets);
    }
}
