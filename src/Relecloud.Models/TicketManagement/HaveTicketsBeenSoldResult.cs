using Relecloud.Web.Models.Services;

namespace Relecloud.Web.Models.TicketManagement
{
    public class HaveTicketsBeenSoldResult : IServiceProviderResult
    {
        public bool HaveTicketsBeenSold { get; set; }
        public string ErrorMessage { get; set; } = string.Empty;
    }
}
