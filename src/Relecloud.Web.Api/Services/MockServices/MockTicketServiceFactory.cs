using Relecloud.Web.Api.Services.TicketManagementService;
using Relecloud.Web.Models.ConcertContext;

namespace Relecloud.Web.Api.Services.MockServices
{
    public class MockTicketServiceFactory : ITicketServiceFactory
    {
        private readonly ITicketManagementService ticketManagementService;

        public MockTicketServiceFactory(ITicketManagementService ticketManagementService)
        {
            this.ticketManagementService = ticketManagementService;
        }

        public ITicketManagementService GetTicketManagementService(TicketManagementServiceProviders provider)
        {
            return this.ticketManagementService;
        }
    }
}
