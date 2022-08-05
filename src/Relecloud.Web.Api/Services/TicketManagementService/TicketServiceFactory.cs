using Relecloud.Web.Models.ConcertContext;
using System.Reflection;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public class TicketServiceFactory : ITicketServiceFactory
    {
        private readonly IEnumerable<ITicketManagementService> services;
        private readonly IDictionary<TicketManagementServiceProviders, ITicketManagementService> serviceProviders;

        public TicketServiceFactory(IEnumerable<ITicketManagementService> services)
        {
            this.services = services;
            this.serviceProviders = new Dictionary<TicketManagementServiceProviders, ITicketManagementService>();
        }

        public ITicketManagementService GetTicketManagementService(TicketManagementServiceProviders provider)
        {
            if (!this.serviceProviders.Any())
            {
                foreach(var service in this.services)
                {
                    var serviceType = service.GetServiceType();
                    this.serviceProviders[serviceType] = service;
                }
            }

            return this.serviceProviders[provider];
        }
    }
}
