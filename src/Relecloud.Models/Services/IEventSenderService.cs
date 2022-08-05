using Relecloud.Web.Models.Events;

namespace Relecloud.Web.Models.Services
{
    public interface IEventSenderService
    {
        Task SendEventAsync(Event eventMessage);
    }
}