using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Services;

namespace Relecloud.Web.Api.Services
{
    public interface IConcertRepository : IConcertContextService
    {
        public void Initialize();
        Task<CreateResult> CreateCustomerAsync(Customer newCustomer);
        Task<Customer?> GetCustomerByEmailAsync(string email);
    }
}
