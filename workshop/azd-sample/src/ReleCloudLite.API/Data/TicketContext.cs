using Microsoft.EntityFrameworkCore;
using ReleCloudLite.Models;

namespace ReleCloudLite.API.Data
{
    public class TicketContext:DbContext
    {
        public TicketContext(DbContextOptions<TicketContext> options) : base(options){}

        public DbSet<Ticket> Tickets { get; set; } = null!;
    }
}
