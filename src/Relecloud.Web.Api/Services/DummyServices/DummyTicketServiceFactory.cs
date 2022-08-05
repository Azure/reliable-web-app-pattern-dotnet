using Relecloud.Web.Api.Services.TicketManagementService;
using Relecloud.Web.Models.ConcertContext;

namespace Relecloud.Web.Api.Services.DummyServices
{
    public class DummyTicketServiceFactory : ITicketServiceFactory
    {
        private readonly ITicketManagementService ticketManagementService;

        public DummyTicketServiceFactory(ITicketManagementService ticketManagementService)
        {
            this.ticketManagementService = ticketManagementService;
        }

        public ITicketManagementService GetTicketManagementService(TicketManagementServiceProviders provider)
        {
            return this.ticketManagementService;
        }
    }
}
