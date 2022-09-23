using Relecloud.Web.Api.Services.TicketManagementService;

namespace Relecloud.Web.Api.Services.MockServices
{
    public class MockTicketRenderingService : ITicketRenderingService
    {
        public Task CreateTicketImageAsync(int ticketId)
        {
            return Task.CompletedTask;
        }
    }
}
