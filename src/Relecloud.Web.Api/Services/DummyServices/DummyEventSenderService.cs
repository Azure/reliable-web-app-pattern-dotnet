using Relecloud.Web.Models.Events;

namespace Relecloud.Web.Api.Services.DummyServices
{
    public class DummyEventSenderService : IAzureEventSenderService
    {
        public void Initialize()
        {
        }

        public Task SendEventAsync(Event eventMessage)
        {
            return Task.CompletedTask;
        }
    }
}