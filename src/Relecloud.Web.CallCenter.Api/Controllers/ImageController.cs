using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;

using Relecloud.Web.Api.Services.TicketManagementService;

namespace Relecloud.Web.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ImageController : ControllerBase
    {
        private ITicketImageService ticketImageService;
        private ILogger<ImageController> logger;

        public ImageController(ITicketImageService ticketImageService, ILogger<ImageController> logger)
        {
            this.ticketImageService = ticketImageService;
            this.logger = logger;
        }

        [HttpGet("{imageName}")]
        [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(byte[]))]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [Authorize]
        public async Task<IActionResult> GetTicketImage(string imageName)
        {
            try
            {
                if (imageName.IsNullOrEmpty())
                {
                    return BadRequest();
                }

                var imageStream = await this.ticketImageService.GetTicketImagesAsync(imageName);
                return File(imageStream, "application/octet-stream");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, $"Unable to retrive image {imageName}");
                return Problem("Unable to get the image");
            }
        }
    }
}