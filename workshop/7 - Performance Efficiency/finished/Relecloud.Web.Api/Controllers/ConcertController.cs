using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Relecloud.Web.Api.Infrastructure;
using Relecloud.Web.Api.Services;
using Relecloud.Web.Api.Services.TicketManagementService;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Services;
using System.Net;
using System.Net.Mime;
using System.Text.Json;

namespace Relecloud.Web.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ConcertController : ControllerBase
    {
        public const int DefaultNumberOfConcerts = 10;

        private readonly ILogger<ConcertController> logger;
        private readonly ITicketManagementService ticketService;
        private readonly IConcertRepository concertRepository;

        public ConcertController(ILogger<ConcertController> logger, ITicketManagementService ticketService, IConcertRepository concertRepository)
        {
            this.logger = logger;
            this.ticketService = ticketService;
            this.concertRepository = concertRepository;
        }

        [HttpGet("{id}", Name = "GetConcertById")]
        [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(Concert))]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult> GetAsync(int id)
        {
            try
            {
                var concert = await this.concertRepository.GetConcertByIdAsync(id);
                if (concert == null)
                {
                    return NotFound();
                }
                concert.NumberOfTicketsForSale = await CountAvailableTicketsAsync(concert.Id);

                return Ok(concert);
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, "Unhandled exception from ConcertController.CreateAsync");
                return Problem("Unable to Get the concert");
            }
        }

        [HttpPost(Name = "CreateConcert")]
        [Consumes(MediaTypeNames.Application.Json)]
        [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(Concert))]
        [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(CreateResult))]
        [Authorize(Roles.Administrator)]
        public async Task<IActionResult> CreateAsync(Concert model)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    return BadRequest(new CreateResult
                    {
                        Success = false,
                        ErrorMessages = ModelState.ConvertToErrorMessages()
                    });
                }
                else if (model.IsVisible && !await AreTicketsAvailableAsync(model.Id))
                {
                    return BadRequest(new CreateResult
                    {
                        Success = false,
                        ErrorMessages = ModelState.ServerError("Cannot make a concert visible if tickets are not available for sale")
                    });
                }

                var newConcertResult = await this.concertRepository.CreateConcertAsync(model);

                return CreatedAtRoute("GetConcertById", new { id = newConcertResult.NewId }, model);
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, "Unhandled exception from ConcertController.CreateAsync");
                return Problem("Unable to Create the concert");
            }
        }

        [HttpPut(Name = "UpdateConcert")]
        [Consumes(MediaTypeNames.Application.Json)]
        [ProducesResponseType(StatusCodes.Status202Accepted, Type = typeof(Concert))]
        [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(UpdateResult))]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [Authorize(Roles.Administrator)]
        public async Task<IActionResult> UpdateAsync(Concert model)
        {
            try
            {
                var existingConcert = await this.concertRepository.GetConcertByIdAsync(model.Id);
                if (existingConcert == null)
                {
                    return NotFound();
                }
                else if (!ModelState.IsValid)
                {
                    return BadRequest(new UpdateResult
                    {
                        Success = false,
                        ErrorMessages = ModelState.ConvertToErrorMessages()
                    });
                }
                else if (model.IsVisible
                    && model.NumberOfTicketsForSale != await CountAvailableTicketsAsync(model.Id))
                {
                    return BadRequest(new UpdateResult
                    {
                        Success = false,
                        ErrorMessages = ModelState.ServerError("Cannot change count of available tickets while concert is visible")
                    });
                }
                else if (model.IsVisible && !await AreTicketsAvailableAsync(model.Id))
                {
                    return BadRequest(new UpdateResult
                    {
                        Success = false,
                        ErrorMessages = ModelState.ServerError("Cannot make a concert visible if tickets are not available for sale")
                    });
                }

                await this.concertRepository.UpdateConcertAsync(model);

                return Accepted(model);
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, "Unhandled exception from ConcertController.UpdateAsync");
                return Problem("Unable to Update the concert");
            }
        }

        [HttpDelete("{id}", Name = "DeleteConcert")]
        [Consumes(MediaTypeNames.Application.Json)]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(DeleteResult))]
        [Authorize(Roles.Administrator)]
        public async Task<IActionResult> DeleteAsync(int id)
        {
            try
            {
                var concert = await this.concertRepository.GetConcertByIdAsync(id);

                if (concert == null)
                {
                    return NotFound();
                }
                else if (concert.IsVisible)
                {
                    return BadRequest(new DeleteResult
                    {
                        Success = false,
                        ErrorMessages = ModelState.ServerError("Visible concerts cannot be deleted")
                    });
                }
                else if (await HaveTicketsBeenSoldAsync(concert.Id))
                {
                    return BadRequest(new DeleteResult
                    {
                        Success = false,
                        ErrorMessages = ModelState.ServerError("Cannot delete a concert that has sold tickets")
                    });
                }

                await this.concertRepository.DeleteConcertAsync(id);
                return Ok();
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, "Unhandled exception from ConcertController.DeleteAsync");
                return Problem("Unable to Delete the concert");
            }
        }

        [HttpGet("GetUpcomingConcerts/{numberOfConcerts?}", Name = "GetUpcomingConcerts")]
        [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(ICollection<Concert>))]
        public async IAsyncEnumerable<Concert> GetUpcomingConcertsAsync(int numberOfConcerts = DefaultNumberOfConcerts)
        {
            var concerts = await this.concertRepository.GetUpcomingConcertsAsync(numberOfConcerts);

            foreach (var concert in concerts)
            {
                yield return concert;
            }
        }

        [HttpGet("GetConcertsByIds", Name = "GetConcertsByIds")]
        [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(ICollection<Concert>))]
        public async IAsyncEnumerable<Concert> GetConcertsByIdAsync(string listOfIds)
        {
            List<int>? ids;
            try
            {
                ids = JsonSerializer.Deserialize<List<int>>(listOfIds);
            }
            catch
            {
                ids = new List<int>();
            }

            var concerts = await this.concertRepository.GetConcertsByIdAsync(ids!);

            foreach (var concert in concerts)
            {
                yield return concert;
            }
        }

        private async Task<bool> HaveTicketsBeenSoldAsync(int concertId)
        {
            var result = await this.ticketService.HaveTicketsBeenSoldAsync(concertId);
            TicketManagementResultGuardClause(result);
            return result.HaveTicketsBeenSold;
        }

        private async Task<bool> AreTicketsAvailableAsync(int concertId)
        {
            return await CountAvailableTicketsAsync(concertId) > 0;
        }

        private async Task<int> CountAvailableTicketsAsync(int concertId)
        {
            var result = await this.ticketService.CountAvailableTicketsAsync(concertId);
            TicketManagementResultGuardClause(result);
            return result.CountOfAvailableTickets;
        }

        private static void TicketManagementResultGuardClause<T>(T result) where T : IServiceProviderResult
        {
            if (!string.IsNullOrEmpty(result.ErrorMessage))
            {
                throw new InvalidOperationException("Error invoking ticket management service", new WebException(result.ErrorMessage));
            }
        }
    }
}
