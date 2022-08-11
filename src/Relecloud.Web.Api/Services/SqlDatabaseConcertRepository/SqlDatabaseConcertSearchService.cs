using Relecloud.Web.Api.Services.SqlDatabaseConcertRepository;
using Relecloud.Web.Models.Search;
using Relecloud.Web.Models.Services;

namespace Relecloud.Web.Services.AzureSearchService
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
            var concertResults = this.database.Concerts
                .Select(c => new ConcertSearchResult{
                    Artist = c.Artist,
                    Description = c.Description,
                    Genre = c.Genre,
                    Id = c.Id.ToString(),
                    Price = c.Price,
                    Title = c.Title
                })
                .ToList();
            
            var searchResponse = new SearchResponse<ConcertSearchResult>(request, concertResults, new List<SearchFacet>());
            searchResponse.TotalCount = concertResults.Count;

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
            var concertsStartingWithName = this.database.Concerts
                            .Where(c => c.Title.ToLower().StartsWith(query))
                            .Select(c => c.Title);
            var artistsStartingWithName = this.database.Concerts
                            .Where(c => c.Artist.ToLower().StartsWith(query))
                            .Select(c => c.Artist);

            var concertResults = concertsStartingWithName
                            .Union(artistsStartingWithName);
            
            return Task.FromResult<ICollection<string>>(concertResults.ToList());
        }

        #endregion

    }
}