using ReleCloudLite.API.Data;
using ReleCloudLite.Models;

namespace ReleCloudLite.API.Mocks
{
    public class MockTicketContext : ITicketContext
    {
        private readonly List<Ticket> _tickets = new List<Ticket>
            {
                new Ticket
                {
                    Id = 1,
                    ShowName = "Amari Rivera - The Tour",
                    Band = "Amari Rivera",
                    Location = "Contoso Stadium",
                    TicketsRemaining = 100,
                    Date = DateTimeOffset.Now.AddDays(7),
                    Price = 50.0f
                },
                new Ticket
                {
                    Id = 2,
                    ShowName = "Centrell World Tour",
                    Band = "Sam Centrell",
                    Location = "Northwind Traders Arena",
                    TicketsRemaining = 200,
                    Date = DateTimeOffset.Now.AddDays(14),
                    Price = 75.0f
                },
                new Ticket
                {
                    Id = 3,
                    ShowName = "Lunatics Live",
                    Band = "Lunatics",
                    Location = "Humongous Insurance Stadium",
                    TicketsRemaining = 150,
                    Date = DateTimeOffset.Now.AddDays(21),
                    Price = 100.0f
                },
                new Ticket
                {
                    Id = 4,
                    ShowName = "Stone",
                    Band = "Carter Theatre Company",
                    Location = "Relecloud Concerts Theatre",
                    TicketsRemaining = 50,
                    Date = DateTimeOffset.Now.AddDays(28),
                    Price = 120.0f
                },
                new Ticket
                {
                    Id = 5,
                    ShowName = "Quinn Campbell Reflections Tour",
                    Band = "Quinn Campbell",
                    Location = "Fabrikam Arena",
                    TicketsRemaining = 75,
                    Date = DateTimeOffset.Now.AddDays(35),
                    Price = 90.0f
                }
            };

        public Task<Ticket?> GetTicketAsync(int id)
        {
            return Task.FromResult(_tickets.FirstOrDefault(t => t.Id == id));
        }

        public Task<IEnumerable<Ticket>?> GetTicketsAsync()
        {
            return Task.FromResult<IEnumerable<Ticket>?>(_tickets);
        }
    }
}
