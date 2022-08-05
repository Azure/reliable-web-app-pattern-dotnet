using Relecloud.Web.Models.Services;

namespace Relecloud.Web.Api.Services
{
    public interface IAzureEventSenderService : IEventSenderService
    {
        void Initialize();
    }
}
