using Microsoft.AspNetCore.Mvc;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Search;
using Relecloud.Web.Models.Services;
using System.Net.Mime;

namespace Relecloud.Web.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class SearchController : ControllerBase
    {
        private ILogger<SearchController> logger;
        private readonly IConcertSearchService concertSearchService;

        public SearchController(ILogger<SearchController> logger, IConcertSearchService concertSearchService)
        {
            this.logger = logger;
            this.concertSearchService = concertSearchService;
        }

        [HttpPost("Concerts", Name = "SearchConcerts")]
        [Consumes(MediaTypeNames.Application.Json)]
        [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(SearchResponse<Concert>))]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> SearchConcertsAsync([FromBody] SearchRequest searchRequest)
        {
            try
            {
                var response = await this.concertSearchService.SearchAsync(searchRequest);
                return Ok(response);
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, $"Unable to display search results for query '{searchRequest.Query}'");
                return Problem($"Unable to display search results for query '{searchRequest.Query}'");
            }
        }

        [HttpGet("SuggestConcerts", Name = "SuggestConcerts")]
        [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(ICollection<string>))]
        public async Task<IActionResult> SuggestConcertsAsync(string query)
        {
            try
            {
                var suggestions = await this.concertSearchService.SuggestAsync(query);
                return Ok(suggestions);
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, $"Unable to suggest search results for query '{query}'");
                return Problem($"Unable to suggest search results for query '{query}'");
            }
        }
    }
}
