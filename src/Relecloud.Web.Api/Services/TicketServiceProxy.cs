using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using Relecloud.Web.Api.Infrastructure;
using Relecloud.Web.Api.Services.SqlDatabaseConcertRepository;
using Relecloud.Web.Api.Services.TicketManagementService;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.TicketManagement;
using System.Text.Json;

namespace Relecloud.Web.Api.Services
{
    public class TicketServiceProxy : ITIcketServiceProxy
    {
        private readonly IConcertRepository concertRepository;
        private readonly ITicketServiceFactory ticketServiceFactory;
        private readonly IDistributedCache cache;
        private readonly ConcertDataContext database;

        public TicketServiceProxy(IConcertRepository concertRepository, ConcertDataContext concertDataContext, ITicketServiceFactory ticketServiceFactory, IDistributedCache cache)
        {
            this.concertRepository = concertRepository;
            this.database = concertDataContext;
            this.ticketServiceFactory = ticketServiceFactory;
            this.cache = cache;
        }

        public async Task<CountAvailableTicketsResult> CountAvailableTicketsAsync(int concertId)
        {
            var service = await GetServiceForConcertAsync(concertId);
            return await service.CountAvailableTicketsAsync(concertId);
        }

        private async Task<ITicketManagementService> GetServiceForConcertAsync(int concertId)
        {
            IDictionary<int, TicketManagementServiceProviders>? serviceMap = null;
            var serviceJson = await this.cache.GetStringAsync(CacheKeys.ConcertIdServiceMap);
            if (serviceJson != null)
            {
                // We have cached data, deserialize the JSON data.
                serviceMap = JsonSerializer.Deserialize<IDictionary<int, TicketManagementServiceProviders>>(serviceJson);
            }
            
            if (serviceMap is null)
            {
                serviceMap = new Dictionary<int, TicketManagementServiceProviders>();
            }

            if (!serviceMap.ContainsKey(concertId))
            {
                var concert = await this.concertRepository.GetConcertByIdAsync(concertId);
                if (concert is null)
                {
                    throw new InvalidOperationException("ConcertId not found");
                }

                serviceMap[concertId] = concert.TicketManagementServiceProvider;
            }
                 
            return ticketServiceFactory.GetTicketManagementService(serviceMap[concertId]);
        }

        public async Task<HaveTicketsBeenSoldResult> HaveTicketsBeenSoldAsync(int concertId)
        {
            var service = await GetServiceForConcertAsync(concertId);
            return await service.HaveTicketsBeenSoldAsync(concertId);
        }

        public async Task<ReserveTicketsResult> ReserveTicketsAsync(IDictionary<int, int> concertIdsAndTicketCounts, string userId)
        {
            //across (perhaps) multiple DbContexts I need to create a bounded transaction
            var strategy = this.database.Database.CreateExecutionStrategy();

            var listOfTicketNumbers = new List<string>();

            await strategy.ExecuteAsync(async () =>
            {
                using var transaction = await this.database.Database.BeginTransactionAsync();

                foreach (var concertId in concertIdsAndTicketCounts.Keys)
                {
                    var service = await GetServiceForConcertAsync(concertId);
                    var reserveResult = await service.ReserveTicketsAsync(concertId, userId, concertIdsAndTicketCounts[concertId]);
                    if (reserveResult.Status != ReserveTicketsResultStatus.Success)
                    {
                        throw new Exception(reserveResult.ErrorMessage);
                    }
                }

                await transaction.CommitAsync();
            });

            return new ReserveTicketsResult
            {
                Status = ReserveTicketsResultStatus.Success,
            };
        }
    }
}
