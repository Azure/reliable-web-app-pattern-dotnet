using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Relecloud.Web.Infrastructure;
using Relecloud.Web.Models;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Services;

namespace Relecloud.Web.Controllers
{
    [Authorize]
    public class TicketController : Controller
    {
        #region Fields

        private readonly ILogger<TicketController> logger;
        private readonly IConcertContextService concertService;

        #endregion

        #region Constructors

        public TicketController(IConcertContextService concertService, ILogger<TicketController> logger)
        {
            this.concertService = concertService;
            this.logger = logger;
        }

        #endregion

        #region Index

        public async Task<IActionResult> Index(int currentPage)
        {
            try
            {
                var userId = this.User.GetUniqueId();
                var pagedResultModel = await this.concertService.GetAllTicketsAsync(userId, currentPage * TicketViewModel.DefaultPageSize, TicketViewModel.DefaultPageSize);

                return View(new TicketViewModel
                {
                    CurrentPage = currentPage,
                    TotalCount = pagedResultModel?.TotalCount ?? 0,
                    Tickets = pagedResultModel?.PageOfData ?? new List<Ticket>()
                });
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Unable to retrieve upcoming concerts");
                return View();
            }
        }

        #endregion
    }
}