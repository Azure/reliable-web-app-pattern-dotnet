using Microsoft.AspNetCore.Mvc;
using Relecloud.Web.Api.Services;
using Relecloud.Web.Models.ConcertContext;
using System.Net.Mime;

namespace Relecloud.Web.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class UserController : ControllerBase
    {
        private readonly ILogger<UserController> logger;
        private readonly IConcertRepository concertRepository;

        public UserController(ILogger<UserController> logger, IConcertRepository concertRepository)
        {
            this.logger = logger;
            this.concertRepository = concertRepository;
        }

        [HttpGet("{id}", Name = "GetUserById")]
        [Consumes(MediaTypeNames.Application.Json)]
        [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(User))]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetAsync(string id)
        {
            try
            {
                var user = await this.concertRepository.GetUserByIdAsync(id);

                if (user == null)
                {
                    return NotFound();
                }

                return Ok(user);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Unhandled exception from UserController.GetAsync");
                return Problem("Unable to GetAsync this user");
            }
        }

        [HttpPatch("", Name = "CreateOrUpdateUser")]
        [Consumes(MediaTypeNames.Application.Json)]
        [ProducesResponseType(StatusCodes.Status202Accepted)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<IActionResult> CreateOrUpdateUserAsync(User model)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    return BadRequest();
                }

                await this.concertRepository.CreateOrUpdateUserAsync(model);

                return Accepted();
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Unhandled exception from UserController.CreateOrUpdateUserAsync");
                return Problem("Unable to CreateOrUpdateUserAsync the user");
            }
        }
    }
}
