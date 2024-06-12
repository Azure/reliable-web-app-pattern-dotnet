using Relecloud.Web.Api.Services.SqlDatabaseConcertRepository;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Search;
using Relecloud.Web.Models.Services;

namespace Relecloud.Web.Api.Services.Search
{
    public class SqlDatabaseConcertSearchService : IConcertSearchService
    {
        private readonly ConcertDataContext database;

        #region Constructors

        public SqlDatabaseConcertSearchService(ConcertDataContext database)
        {
            this.database = database;
        }

        #endregion

        #region Search

        public Task<SearchResponse<ConcertSearchResult>> SearchAsync(SearchRequest request)
        {
            var query = request.Query.ToLower();

            var concertsStartingWithName = database.Concerts
                .Where(c => c.Title.ToLower().Contains(query))
                .Select(c => new ConcertSearchResult
                {
                    Artist = c.Artist,
                    Description = c.Description,
                    Genre = c.Genre,
                    Id = c.Id.ToString(),
                    Price = c.Price,
                    Title = c.Title,
                    StartTime = c.StartTime
                });
            var artistsStartingWithName = database.Concerts
                .Where(c => c.Artist.ToLower().Contains(query))
                .Select(c => new ConcertSearchResult
                {
                    Artist = c.Artist,
                    Description = c.Description,
                    Genre = c.Genre,
                    Id = c.Id.ToString(),
                    Price = c.Price,
                    Title = c.Title,
                    StartTime = c.StartTime
                });

            var concertResults = concertsStartingWithName.Union(artistsStartingWithName);

            if (request.SortOn == nameof(Concert.Price) && request.SortDescending)
            {
                concertResults = concertResults.OrderByDescending(c => c.Price);
            }
            else if (request.SortOn == nameof(Concert.Price))
            {
                concertResults = concertResults.OrderBy(c => c.Price);
            }
            else if (request.SortOn == nameof(Concert.StartTime) && request.SortDescending)
            {
                concertResults = concertResults.OrderByDescending(c => c.StartTime);
            }
            else if (request.SortOn == nameof(Concert.StartTime))
            {
                concertResults = concertResults.OrderBy(c => c.StartTime);
            }

            var searchResponse = new SearchResponse<ConcertSearchResult>(request, concertResults.ToList(), new List<SearchFacet>());
            searchResponse.TotalCount = concertResults.Count();

            return Task.FromResult(searchResponse);
        }

        #endregion

        #region Suggest

        public Task<ICollection<string>> SuggestAsync(string query)
        {
            if (string.IsNullOrWhiteSpace(query))
            {
                return Task.FromResult<ICollection<string>>(new string[0]);
            }

            query = query.ToLower();
            var concertsStartingWithName = database.Concerts
                            .Where(c => c.Title.ToLower().StartsWith(query))
                            .Select(c => c.Title);
            var artistsStartingWithName = database.Concerts
                            .Where(c => c.Artist.ToLower().StartsWith(query))
                            .Select(c => c.Artist);

            var concertResults = concertsStartingWithName
                            .Union(artistsStartingWithName);

            return Task.FromResult<ICollection<string>>(concertResults.ToList());
        }

        #endregion

    }
}