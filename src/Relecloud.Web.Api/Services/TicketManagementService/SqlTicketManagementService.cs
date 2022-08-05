using Microsoft.EntityFrameworkCore;
using Relecloud.Web.Api.Services.SqlDatabaseConcertRepository;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Events;
using Relecloud.Web.Models.TicketManagement;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public class SqlTicketManagementService : ITicketManagementService
    {
        private readonly ConcertDataContext database;
        private readonly IAzureEventSenderService eventSenderService;

        public SqlTicketManagementService(ConcertDataContext database, IAzureEventSenderService eventSenderService)
        {
            this.database = database;
            this.eventSenderService = eventSenderService;
        }

        public async Task<CountAvailableTicketsResult> CountAvailableTicketsAsync(int concertId)
        {
            var count = await this.database.TicketNumbers.CountAsync(tn => tn.ConcertId == concertId);
            return new CountAvailableTicketsResult
            {
                CountOfAvailableTickets = count
            };
        }

        public TicketManagementServiceProviders GetServiceType()
        {
            return TicketManagementServiceProviders.RelecloudApi;
        }

        public async Task<HaveTicketsBeenSoldResult> HaveTicketsBeenSoldAsync(int concertId)
        {
            var count = await this.database.TicketNumbers.CountAsync(tn => tn.ConcertId == concertId && tn.TicketId != null);
            return new HaveTicketsBeenSoldResult
            {
                HaveTicketsBeenSold = count > 0,
            };
        }

        public async Task<ReserveTicketsResult> ReserveTicketsAsync(int concertId, string userId, int numberOfTickets)
        {
            var unusedTicketNumberss = await this.database.TicketNumbers.Where(tn => tn.TicketId == null && tn.ConcertId == concertId)
                .Take(numberOfTickets).ToListAsync();

            foreach (var ticket in unusedTicketNumberss)
            {
                ticket.Ticket = new Ticket
                {
                    ConcertId = concertId,
                    UserId = userId,
                    TicketNumber = ticket.Number
                };
            }

            await this.database.SaveChangesAsync();

            foreach(var ticketNumber in unusedTicketNumberss)
            {
                await this.eventSenderService.SendEventAsync(new Event
                {
                    EntityId = ticketNumber.Ticket.Id.ToString(),
                    EventType = EventType.TicketCreated
                });
            }

            return new ReserveTicketsResult
            {
                TicketNumbers = unusedTicketNumberss.Select(tn => tn.Number).ToList(),
            };
        }
    }
}
