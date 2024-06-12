namespace Relecloud.Web.Models.Search
{
    public class SearchResponse<T>
    {
        public long TotalCount { get; set; }
        public SearchRequest Request { get; set; }
        public ICollection<T> Results { get; set; }
        public ICollection<SearchFacet> Facets { get; set; }

        public SearchResponse(SearchRequest request, ICollection<T> results, ICollection<SearchFacet> facets)
        {
            this.Request = request;
            this.Results = results ?? new T[0];
            this.Facets = facets ?? new SearchFacet[0];
        }
    }
}