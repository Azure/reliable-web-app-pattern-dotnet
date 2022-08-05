using Relecloud.Web.Models.Search;
using Relecloud.Web.Models.Services;

namespace Relecloud.Web.Services.DummyServices
{
    public class DummyConcertSearchService : IConcertSearchService
    {
        public void Initialize()
        {
        }

        public Task<SearchResponse<ConcertSearchResult>> SearchAsync(SearchRequest request)
        {
            return Task.FromResult(new SearchResponse<ConcertSearchResult>(request, Array.Empty<ConcertSearchResult>(), Array.Empty<SearchFacet>()));
        }

        public Task<ICollection<string>> SuggestAsync(string query)
        {
            return Task.FromResult<ICollection<string>>(Array.Empty<string>());
        }
    }
}