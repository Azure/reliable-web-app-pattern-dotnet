using Microsoft.Extensions.Options;
using Relecloud.Web.Api.Services.SqlDatabaseConcertRepository;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Events;
using Relecloud.Web.Models.TicketManagement;

using MockTicketManagementService = ServiceProviders.TicketManagement.MockTicketManagementService;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public class MockTicketManagementServiceFacade : ITicketManagementService
    {
        private readonly ConcertDataContext database;
        private readonly IConcertRepository concertRepository;
        private readonly MockTicketManagementService mockTicketManagementService;
        private readonly IAzureEventSenderService eventSenderService;

        public MockTicketManagementServiceFacade(HttpClient client, IOptions<TicketManagementServiceOptions> options, IConcertRepository concertRepository, ConcertDataContext database, IAzureEventSenderService eventSenderService)
        {
            this.mockTicketManagementService = new MockTicketManagementService(client);
            if (!string.IsNullOrEmpty(options?.Value?.BaseUri))
            {
                this.mockTicketManagementService.BaseUrl = options.Value.BaseUri;
            }
            this.concertRepository = concertRepository;
            this.database = database;
            this.eventSenderService = eventSenderService;
        }

        private async Task<string> GetExternalConcertIdAsync(int concertId)
        {
            var concert = await concertRepository.GetConcertByIdAsync(concertId);
            return concert?.TicketManagementServiceConcertId ?? concertId.ToString();
        }

        public async Task<CountAvailableTicketsResult> CountAvailableTicketsAsync(int concertId)
        {
            var externalConcertId = await GetExternalConcertIdAsync(concertId);
            var result = await this.mockTicketManagementService.CountAvailableTicketsAsync(externalConcertId);
            return new CountAvailableTicketsResult
            {
                CountOfAvailableTickets = result.CountOfAvailableTickets.GetValueOrDefault(),
                ErrorMessage = result.ErrorMessage,
            };
        }

        public TicketManagementServiceProviders GetServiceType()
        {
            return TicketManagementServiceProviders.MockTicketManagementService;
        }

        public async Task<HaveTicketsBeenSoldResult> HaveTicketsBeenSoldAsync(int concertId)
        {
            var externalConcertId = await GetExternalConcertIdAsync(concertId);
            var result = await this.mockTicketManagementService.HaveTicketsBeenSoldAsync(externalConcertId);
            return new HaveTicketsBeenSoldResult
            {
                HaveTicketsBeenSold = result.HaveTicketsBeenSold.GetValueOrDefault(),
                ErrorMessage = result.ErrorMessage,
            };
        }

        public async Task<ReserveTicketsResult> ReserveTicketsAsync(int concertId, string userId, int numberOfTickets)
        {
            var externalConcertId = await GetExternalConcertIdAsync(concertId);
            var result = await this.mockTicketManagementService.ReserveTicketsAsync(externalConcertId, userId, numberOfTickets);

            var newTickets = new List<Ticket>();
            foreach(var ticketNumber in result.TicketNumbers)
            {
                var newTicket = new Ticket
                {
                    ConcertId = concertId,
                    UserId = userId,
                    TicketNumber = ticketNumber
                };
                newTickets.Add(newTicket);
                this.database.Tickets.Add(newTicket);
            }
            await this.database.SaveChangesAsync();

            foreach (var ticket in newTickets)
            {
                await this.eventSenderService.SendEventAsync(new Event
                {
                    EntityId = ticket.Id.ToString(),
                    EventType = EventType.TicketCreated
                });
            }

            return new ReserveTicketsResult
            {
                TicketNumbers = result.TicketNumbers,
                ErrorMessage = result.ErrorMessage,
                Status = (ReserveTicketsResultStatus) (int)result.Status.GetValueOrDefault(),
            };
        }
    }
}
