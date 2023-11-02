using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Relecloud.Web.Api.Infrastructure;
using Relecloud.Web.Api.Services.TicketManagementService;
using Relecloud.Web.Api.Services;
using Relecloud.Web.Models.ConcertContext;
using System.Net.Mime;
using static Microsoft.ApplicationInsights.MetricDimensionNames.TelemetryContext;
using Microsoft.Extensions.Primitives;
using Microsoft.Extensions.Logging;

namespace Relecloud.Web.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class CartController : ControllerBase
    {
        private readonly ILogger<CartController> logger;
        private readonly ICartRepository cartRepository;

        public CartController(ILogger<CartController> logger, ICartRepository cartRepository)
        {
            this.logger = logger;
            this.cartRepository = cartRepository;
        }

        [HttpPut(Name = "AddToCart")]
        [Consumes(MediaTypeNames.Application.Json)]
        [ProducesResponseType(StatusCodes.Status202Accepted)]
        public async Task<IActionResult> UpdateAsync(string userId, int concertId, int count)
        {
            var operationName = "CART_ADD";
            try
            {
                await this.cartRepository.UpdateCartAsync(userId, concertId, count);
                this.logger.LogInformation(Request.ExtractOperationBreadcrumb("OK", operationName).Serialize());
                return Accepted();
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, "Unhandled exception from ConcertController.UpdateAsync");
                this.logger.LogError(Request.ExtractOperationBreadcrumb("ERROR", operationName).Serialize());
                return Problem("Unable to Update the concert");
            }
        }

        [HttpGet(Name = "GetCart")]
        [Consumes(MediaTypeNames.Application.Json)]
        [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(Dictionary<int, int>))]
        public async Task<IActionResult> GetAsync(string userId)
        {
            var operationName = "CART_GET";
            try
            {
                var cart = await this.cartRepository.GetCartAsync(userId);
                this.logger.LogInformation(Request.ExtractOperationBreadcrumb("OK", operationName).Serialize());
                return Ok(cart);
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, "Unhandled exception from ConcertController.UpdateAsync");
                this.logger.LogError(Request.ExtractOperationBreadcrumb("ERROR", operationName).Serialize());
                return Problem("Unable to Update the concert");
            }
        }

        [HttpDelete(Name = "ClearCart")]
        [Consumes(MediaTypeNames.Application.Json)]
        [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(Dictionary<int, int>))]
        public async Task<IActionResult> ClearAsync(string userId)
        {
            try
            {
                await this.cartRepository.ClearCartAsync(userId);
                return Ok();
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, "Unhandled exception from ConcertController.UpdateAsync");
                return Problem("Unable to Update the concert");
            }
        }

    }
}
