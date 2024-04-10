using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

using Relecloud.Web.CallCenter.Services;

namespace Relecloud.Web.CallCenter.Controllers;

[Route("webapi/[controller]")]
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
    [Authorize]
    public async Task<IActionResult> GetTicketImage(string imageName)
    {
        try
        {
            var imageStream = await this.ticketImageService.GetTicketImagesAsync(imageName);

            return File(imageStream, "application/octet-stream");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, $"Unable to retrive image: {imageName}");
            return Problem("Unable to get the image");
        }
    }
}