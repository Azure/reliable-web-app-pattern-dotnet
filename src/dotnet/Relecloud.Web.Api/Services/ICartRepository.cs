namespace Relecloud.Web.Api.Services
{
    public interface ICartRepository
    {
        Task ClearCartAsync(string userId);
        Task<Dictionary<int, int>> GetCartAsync(string userId);
        Task UpdateCartAsync(string userId, int concertId, int count);
    }
}
