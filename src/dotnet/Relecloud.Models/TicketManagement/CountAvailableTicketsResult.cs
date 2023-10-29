using Relecloud.Web.Models.Services;

namespace Relecloud.Web.Models.TicketManagement
{
    public class CountAvailableTicketsResult : IServiceProviderResult
    {
        public int CountOfAvailableTickets { get; set; }
        public string ErrorMessage { get; set; } = string.Empty;
    }
}
