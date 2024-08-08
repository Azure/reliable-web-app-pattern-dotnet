using Microsoft.EntityFrameworkCore;
using ReleCloudLite.API.Data;
using ReleCloudLite.Models;

namespace ReleCloudLite.API.Service
{
    public class TicketService
    {
        private readonly TicketContext _context;

        public TicketService(TicketContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<Ticket>?> GetTicketsAsync()
        {
            return await _context.Tickets.AsNoTracking().ToListAsync();
        }

        public async Task<Ticket?> GetTicketAsync(int id)
        {
            var ticket = await _context.Tickets.FindAsync(id);

            return ticket;
        }
    }
}
