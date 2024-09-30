using ReleCloudLite.Models;

namespace ReleCloudLite.API.Data
{
    public interface ITicketContext
    {
        Task<IEnumerable<Ticket>?> GetTicketsAsync();
        Task<Ticket?> GetTicketAsync(int id);
    }
}
