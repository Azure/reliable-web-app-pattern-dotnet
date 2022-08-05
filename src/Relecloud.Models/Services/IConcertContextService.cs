using Relecloud.Web.Models.ConcertContext;

namespace Relecloud.Web.Models.Services
{
    public interface IConcertContextService
    {
        Task<CreateResult> CreateConcertAsync(Concert newConcert);
        Task<UpdateResult> UpdateConcertAsync(Concert model);
        Task<DeleteResult> DeleteConcertAsync(int id);
        Task<Concert?> GetConcertByIdAsync(int id);
        Task<ICollection<Concert>> GetConcertsByIdAsync(ICollection<int> ids);
        Task<ICollection<Concert>> GetUpcomingConcertsAsync(int count);

        Task<Ticket?> GetTicketByIdAsync(int id);
        Task<PagedResult<Ticket>> GetAllTicketsAsync(string userId, int skip, int take);

        Task<UpdateResult> CreateOrUpdateUserAsync(User user);
        Task<User?> GetUserByIdAsync(string id);
    }
}