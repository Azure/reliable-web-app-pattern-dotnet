using Relecloud.Web.Api.Services;

namespace Relecloud.Web.Api.Infrastructure
{
    public class ApplicationInitializer
    {
        private readonly IConcertRepository concertContextService;
        private readonly IAzureEventSenderService eventSenderService;

        public ApplicationInitializer(IConcertRepository concertContextService, IAzureEventSenderService eventSenderService)
        {
            this.concertContextService = concertContextService;
            this.eventSenderService = eventSenderService;
        }

        public void Initialize()
        {
            // Initialize all resources at application startup.
            concertContextService.Initialize();
            eventSenderService.Initialize();
        }
    }
}
