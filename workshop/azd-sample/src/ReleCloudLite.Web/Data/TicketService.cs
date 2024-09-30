using ReleCloudLite.Models;

namespace ReleCloudLite.Web.Data
{
    public class TicketService
    {
        private readonly HttpClient _httpClient;

        public TicketService(HttpClient httpClient)
        {
            _httpClient = httpClient;
        }

        public async Task<IEnumerable<Ticket>?> GetTicketsAsync()
        {
            var getAllTickets = await _httpClient.GetFromJsonAsync<IEnumerable<Ticket>?>("tickets");
            return getAllTickets;
        }

        public async Task<Ticket?> GetTicketAsync(int id)
        {
            var url = $"tickets/{id}";
            var getTicket = await _httpClient.GetFromJsonAsync<Ticket>(url);
            return getTicket;
        }
    }
}
