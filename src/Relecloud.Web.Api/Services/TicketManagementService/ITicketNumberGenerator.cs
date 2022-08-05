namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public interface ITicketNumberGenerator
    {
        string Generate(int ticketNumberLength = 50);
    }
}