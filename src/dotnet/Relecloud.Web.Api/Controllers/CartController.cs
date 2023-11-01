using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Relecloud.Web.Api.Infrastructure;
using Relecloud.Web.Api.Services.TicketManagementService;
using Relecloud.Web.Api.Services;
using Relecloud.Web.Models.ConcertContext;
using System.Net.Mime;

namespace Relecloud.Web.Api.Controllers
{
    public class CartController : Controller
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
            try
            {
                await this.cartRepository.UpdateCartAsync(userId, concertId, count);
                return Accepted();
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, "Unhandled exception from ConcertController.UpdateAsync");
                return Problem("Unable to Update the concert");
            }
        }

        [HttpGet(Name = "GetCart")]
        [Consumes(MediaTypeNames.Application.Json)]
        [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(Dictionary<int, int>))]
        public async Task<IActionResult> GetAsync(string userId)
        {
            try
            {
                var cart = await this.cartRepository.GetCartAsync(userId);
                return Ok(cart);
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, "Unhandled exception from ConcertController.UpdateAsync");
                return Problem("Unable to Update the concert");
            }
        }

    }
}
