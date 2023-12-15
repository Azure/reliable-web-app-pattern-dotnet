namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public interface ITicketRenderingService
    {
        public Task CreateTicketImageAsync(int ticketId);
    }
}
