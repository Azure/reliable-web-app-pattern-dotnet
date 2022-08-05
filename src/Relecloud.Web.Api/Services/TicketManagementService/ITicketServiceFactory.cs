using Relecloud.Web.Models.ConcertContext;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public interface ITicketServiceFactory
    {
        public ITicketManagementService GetTicketManagementService(TicketManagementServiceProviders provider);
    }
}
