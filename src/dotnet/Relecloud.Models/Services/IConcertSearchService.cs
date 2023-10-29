using Relecloud.Web.Models.Search;

namespace Relecloud.Web.Models.Services
{
    public interface IConcertSearchService
    {
        Task<SearchResponse<ConcertSearchResult>> SearchAsync(SearchRequest request);
        Task<ICollection<string>> SuggestAsync(string query);
    }
}
