using Azure.Identity;
using Azure.Search.Documents;
using Azure.Search.Documents.Models;
using NuGet.Packaging;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Search;
using Relecloud.Web.Models.Services;

namespace Relecloud.Web.Services.Search
{
    public class AzureSearchConcertSearchService : IConcertSearchService
    {
        #region Constants

        private const string IndexNameConcerts = "concerts";
        private const int PriceFacetInterval = 20;

        #endregion

        #region Fields

        private readonly Uri searchServiceUri;
        private readonly string concertsSqlDatabaseConnectionString;
        private readonly SearchClient concertsIndexClient;

        #endregion

        #region Constructors

        public AzureSearchConcertSearchService(string searchServiceName, string concertsSqlDatabaseConnectionString)
        {
            this.searchServiceUri = new Uri($"https://{searchServiceName}.search.windows.net");
            this.concertsSqlDatabaseConnectionString = concertsSqlDatabaseConnectionString;

            // https://docs.microsoft.com/en-us/azure/architecture/best-practices/retry-service-specific#retry-mechanism-5
            // The default policy retries with exponential backoff when Azure Search returns a 5xx or 408 (Request Timeout) response.
            this.concertsIndexClient = new SearchClient(this.searchServiceUri, IndexNameConcerts, new DefaultAzureCredential());
        }

        #endregion

        #region Search

        public async Task<SearchResponse<ConcertSearchResult>> SearchAsync(SearchRequest request)
        {
            var query = request.Query;
            if (string.IsNullOrWhiteSpace(query))
            {
                query = "*";
            }
            var items = new List<ConcertSearchResult>();

            // Search concerts.
            var concertQueryParameters = new SearchOptions();
            concertQueryParameters.HighlightFields.Add(nameof(Concert.Description));
            concertQueryParameters.OrderBy.AddRange(GetOrderBy(request));
            concertQueryParameters.Facets.AddRange(new[] { $"{nameof(Concert.Price)},interval:{PriceFacetInterval}", nameof(Concert.Genre), nameof(Concert.Location) });
            concertQueryParameters.Filter = GetFilter(request);
            concertQueryParameters.Size = SearchRequest.PageSize;
            concertQueryParameters.Skip = request.CurrentPage * SearchRequest.PageSize;
            concertQueryParameters.IncludeTotalCount = true;

            var concertResults = await this.concertsIndexClient.SearchAsync<ConcertSearchResult>(query, concertQueryParameters);

            foreach (var concertResult in concertResults.Value.GetResults())
            {
                concertResult.Document.HitHighlights = concertResult.Highlights.SelectMany(h => h.Value).ToArray();
                items.Add(concertResult.Document);
            }

            // Process the search facets.
            var facets = new List<SearchFacet>();
            foreach (var facetResultsForField in concertResults.Value.Facets)
            {
                var fieldName = facetResultsForField.Key;
                var facetValues = facetResultsForField.Value.Select(f => GetFacetValue(fieldName, f)).ToArray();
                facets.Add(new SearchFacet(fieldName, fieldName, facetValues));
            }

            var searchResponse = new SearchResponse<ConcertSearchResult>(request, items, facets);
            searchResponse.TotalCount = concertResults.Value.TotalCount ?? 0;

            return searchResponse;
        }

        #endregion

        #region Suggest

        public async Task<ICollection<string>> SuggestAsync(string query)
        {
            if (string.IsNullOrWhiteSpace(query))
            {
                return new string[0];
            }

            var filters = new List<string> { $"({nameof(Concert.IsVisible)}) eq true" };
            var options = new AutocompleteOptions()
            {
                Mode = AutocompleteMode.OneTermWithContext,
                Size = 6,
                Filter = string.Join(" and ", filters)
            };

            // Convert the autocompleteResult results to a list that can be displayed in the client.
            var autocompleteResult = await this.concertsIndexClient.AutocompleteAsync(query, "default-suggester", options).ConfigureAwait(false);

            return autocompleteResult.Value.Results.Select(x => x.Text).ToList();
        }

        #endregion

        #region Helper Methods

        private static IList<string> GetOrderBy(SearchRequest request)
        {
            return new[] { request.SortOn + (request.SortDescending ? " desc" : "") };
        }

        private string GetFilter(SearchRequest request)
        {
            var filters = new List<string>();

            // only visible concerts should be returned by search results
            filters.Add($"({nameof(Concert.IsVisible)}) eq true");

            if (!string.IsNullOrWhiteSpace(request.PriceRange))
            {
                var priceRangeStart = int.Parse(request.PriceRange);
                var priceRangeEnd = priceRangeStart + PriceFacetInterval;
                filters.Add($"({nameof(Concert.Price)} ge {priceRangeStart} and {nameof(Concert.Price)} lt {priceRangeEnd})");
            }
            if (!string.IsNullOrWhiteSpace(request.Genre))
            {
                filters.Add($"({nameof(Concert.Genre)} eq '{request.Genre}')");

            }
            if (!string.IsNullOrWhiteSpace(request.Location))
            {
                filters.Add($"({nameof(Concert.Location)} eq '{request.Location}')");
            }
            return string.Join(" and ", filters);
        }

        private static SearchFacetValue GetFacetValue(string fieldName, FacetResult facetResult)
        {
            var count = facetResult.Count ?? 0;
            if (string.Equals(fieldName, nameof(Concert.Price), StringComparison.OrdinalIgnoreCase))
            {
                var priceRangeStart = Convert.ToInt32(facetResult.Value);
                var priceRangeEnd = priceRangeStart + PriceFacetInterval - 1;
                var value = priceRangeStart.ToString();
                var displayName = $"{priceRangeStart.ToString("c0")} - {priceRangeEnd.ToString("c0")}";
                return new SearchFacetValue(value, displayName, count);
            }
            else
            {
                var value = (string)facetResult.Value;
                return new SearchFacetValue(value, value, count);
            }
        }

        #endregion
    }
}