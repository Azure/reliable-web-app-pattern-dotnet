using Relecloud.Web.Models.Services;

namespace Relecloud.Web.Api.Services
{
    public interface IConcertRepository : IConcertContextService
    {
        public void Initialize();
    }
}
