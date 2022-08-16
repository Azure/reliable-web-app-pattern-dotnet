using Relecloud.Web.Models.Events;

namespace Relecloud.Web.Api.Services.MockServices
{
    public class MockEventSenderService : IAzureEventSenderService
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