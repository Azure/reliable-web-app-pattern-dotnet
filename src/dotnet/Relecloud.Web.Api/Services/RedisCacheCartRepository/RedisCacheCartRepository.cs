using Microsoft.Extensions.Caching.Distributed;
using Newtonsoft.Json;

namespace Relecloud.Web.Api.Services.RedisCacheCartRepository
{
    public class RedisCacheCartRepository : ICartRepository, IDisposable
    {
        private readonly IDistributedCache cache;

        public RedisCacheCartRepository(IDistributedCache cache)
        {
            this.cache = cache;
        }
        public void Dispose()
        {
        }

        public async Task ClearCartAsync(string userId)
        {
            var currentCart = new Dictionary<int, int>();
            await UpdateCartAsync(userId, currentCart);
        }

        public async Task<Dictionary<int, int>> GetCartAsync(string userId)
        {
            var cacheKey = GetCartKey(userId);
            var cartData = await cache.GetStringAsync(cacheKey);
            if(cartData == null)
            {
                return new Dictionary<int, int>();
            } 
            else
            {
                var cartObject = JsonConvert.DeserializeObject<Dictionary<int, int>>(cartData);
                return cartObject ?? new Dictionary<int, int>();
            }
        }

        public async Task UpdateCartAsync(string userId, int concertId, int count)
        {
            var currentCart = await GetCartAsync(userId);

            if(currentCart.ContainsKey(concertId))
            {
                currentCart[concertId] = count;
            }
            else
            {
                currentCart.Add(concertId, count);
            }
            await UpdateCartAsync(userId, currentCart);
        }

        private async Task UpdateCartAsync(string userId, Dictionary<int, int> currentCart)
        {
            var cartData = JsonConvert.SerializeObject(currentCart);
            var cacheOptions = new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1)
            };
            var cacheKey = GetCartKey(userId);
            await cache.SetStringAsync(cacheKey, cartData, cacheOptions);
        }

        private string GetCartKey(string userId)
        {
            return $"{userId}-CART";
        }
    }
}
