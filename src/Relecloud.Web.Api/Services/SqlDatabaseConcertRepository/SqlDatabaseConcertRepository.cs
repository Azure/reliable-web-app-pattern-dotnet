using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using Relecloud.Web.Api.Infrastructure;
using Relecloud.Web.Models.ConcertContext;
using System.Text.Json;

namespace Relecloud.Web.Api.Services.SqlDatabaseConcertRepository
{
    public class SqlDatabaseConcertRepository : IConcertRepository, IDisposable
    {
        private readonly ConcertDataContext database;
        private readonly IDistributedCache cache;

        public SqlDatabaseConcertRepository(ConcertDataContext database, IDistributedCache cache)
        {
            this.database = database;
            this.cache = cache;
        }

        public void Initialize()
        {
            this.database.Initialize();
        }

        public async Task<CreateResult> CreateConcertAsync(Concert newConcert)
        {
            database.Add(newConcert);
            await this.database.SaveChangesAsync();
            this.cache.Remove(CacheKeys.UpcomingConcerts);
            return CreateResult.SuccessResult(newConcert.Id);
        }

        public async Task<UpdateResult> UpdateConcertAsync(Concert existingConcert)
        {
            database.Update(existingConcert);
            await database.SaveChangesAsync();
            this.cache.Remove(CacheKeys.UpcomingConcerts);
            return UpdateResult.SuccessResult();
        }

        public async Task<DeleteResult> DeleteConcertAsync(int concertId)
        {
            var existingConcert = this.database.Concerts.SingleOrDefault(c => c.Id == concertId);
            if (existingConcert != null)
            {
                database.Remove(existingConcert);
                await database.SaveChangesAsync();
                this.cache.Remove(CacheKeys.UpcomingConcerts);
            }

            return DeleteResult.SuccessResult();
        }

        public async Task<Concert?> GetConcertByIdAsync(int id)
        {
            return await this.database.Concerts.AsNoTracking().Where(c => c.Id == id).SingleOrDefaultAsync();
        }

        public async Task<ICollection<Concert>> GetConcertsByIdAsync(ICollection<int> ids)
        {
            return await this.database.Concerts.AsNoTracking().Where(c => ids.Contains(c.Id)).ToListAsync();
        }

        public async Task<ICollection<Concert>> GetUpcomingConcertsAsync(int count)
        {
            IList<Concert>? concerts;
            var concertsJson = await this.cache.GetStringAsync(CacheKeys.UpcomingConcerts);
            if (concertsJson != null)
            {
                // We have cached data, deserialize the JSON data.
                concerts = JsonSerializer.Deserialize<IList<Concert>>(concertsJson);
            }
            else
            {
                // There's nothing in the cache, retrieve data from the repository and cache it for one hour.
                concerts = await this.database.Concerts.AsNoTracking()
                    .Where(c => c.StartTime > DateTimeOffset.UtcNow && c.IsVisible)
                    .OrderBy(c => c.StartTime)
                    .Take(count)
                    .ToListAsync();
                concertsJson = JsonSerializer.Serialize(concerts);
                var cacheOptions = new DistributedCacheEntryOptions {
                    AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1)
                };
                await this.cache.SetStringAsync(CacheKeys.UpcomingConcerts, concertsJson, cacheOptions);
            }
            return concerts ?? new List<Concert>();
        }

        public async Task<UpdateResult> CreateOrUpdateUserAsync(User user)
        {
            var dbUser = await this.database.Users.FindAsync(user.Id);
            if (dbUser == null)
            {
                dbUser = new User { Id = user.Id };
                this.database.Users.Add(dbUser);
            }
            dbUser.DisplayName = user.DisplayName;
            await this.database.SaveChangesAsync();

            return UpdateResult.SuccessResult();
        }

        public async Task<int> GetCountForAllTicketsAsync(string userId)
        {
            return await this.database.Tickets.CountAsync(t => t.UserId == userId);
        }

        public async Task<PagedResult<Ticket>> GetAllTicketsAsync(string userId, int skip, int take)
        {
            var pageOfData = await this.database.Tickets.AsNoTracking().Include(t => t.Concert).Where(t => t.UserId == userId)
                .OrderByDescending(t=> t.Id).Skip(skip).Take(take).ToListAsync();
            var totalCount = await this.database.Tickets.Where(t => t.UserId == userId).CountAsync();

            return new PagedResult<Ticket>(pageOfData, totalCount);
        }

        public void Dispose()
        {
            if (this.database != null)
            {
                this.database.Dispose();
            }
        }

        public async Task<Ticket?> GetTicketByIdAsync(int id)
        {
            return await this.database.Tickets.AsNoTracking().Where(t => t.Id == id).SingleOrDefaultAsync();
        }

        public async Task<User?> GetUserByIdAsync(string id)
        {
            return await this.database.Users.AsNoTracking().Where(u => u.Id == id).SingleOrDefaultAsync();
        }

        public async Task<Customer?> GetCustomerByEmailAsync(string email)
        {
            if (string.IsNullOrEmpty(email))
            {
                return null;
            }

            return await this.database.Customers.AsNoTracking()
                .Where(u => u.Email.ToLower() == email.ToLower()).SingleOrDefaultAsync();
        }

        public async Task<CreateResult> CreateCustomerAsync(Customer newCustomer)
        {
            if (string.IsNullOrEmpty(newCustomer.Email))
            {
                throw new ArgumentNullException(nameof(newCustomer.Email));
            }

            var customer = await this.database.Customers
                .FirstOrDefaultAsync(c => c.Email.ToLower() == newCustomer.Email.ToLower());
            if (customer == null)
            {
                customer = new Customer
                {
                    Id = newCustomer.Id,
                    Email = newCustomer.Email,
                    Name = newCustomer.Name,
                    Phone = newCustomer.Phone,
                };
                this.database.Customers.Add(customer);
                await this.database.SaveChangesAsync();
            }

            return CreateResult.SuccessResult(customer.Id);
        }
    }
}