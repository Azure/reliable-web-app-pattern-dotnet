using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Relecloud.Web.CallCenter.Infrastructure;
using Relecloud.Web.CallCenter.ViewModels;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Search;
using Relecloud.Web.Models.Services;

namespace Relecloud.Web.CallCenter.Controllers
{
    public class ConcertController : Controller
    {
        #region Fields

        private readonly IConcertContextService concertService;
        private readonly IConcertSearchService concertSearchService;
        private readonly ILogger<ConcertController> logger;

        #endregion

        #region Constructors

        public ConcertController(IConcertContextService concertService, IConcertSearchService concertSearchService, ILogger<ConcertController> logger)
        {
            this.concertService = concertService;
            this.concertSearchService = concertSearchService;
            this.logger = logger;
        }

        #endregion

        #region Index

        public async Task<IActionResult> Index()
        {
            try
            {
                var model = await this.concertService.GetUpcomingConcertsAsync(10);
                return View(model);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Unable to retrieve upcoming concerts");
                return View();
            }
        }

        #endregion

        #region Create
        [HttpGet]
        [Authorize(Roles.Administrator)]
        public IActionResult Create()
        {
            return View(new ConcertViewModel
            {
                Concert = new Concert()
            });
        }

        [HttpPost]
        [Authorize(Roles.Administrator)]
        public async Task<IActionResult> Create([Bind(Prefix = "Concert")] Concert model)
        {
            if (ModelState.IsValid)
            {
                try
                {
                    model.CreatedBy = User.Identity?.Name ?? "Unknown";
                    model.UpdatedBy = model.CreatedBy;
                    model.CreatedOn = DateTime.UtcNow;
                    model.UpdatedOn = model.CreatedOn;
                    var newConcertResult = await this.concertService.CreateConcertAsync(model);
                    if (newConcertResult.Success)
                    {
                        return RedirectToAction("Details", new { id = newConcertResult.NewId });
                    }

                    ModelState.AddErrorMessages(newConcertResult.ErrorMessages);
                }
                catch (Exception ex)
                {
                    logger.LogError(ex, "Unhadled exception from ConcertController.Create(model)");
                    ModelState.AddModelError(string.Empty, "Unable to save concerts. Please try again later.");
                }
            }

            return View(new ConcertViewModel
            {
                Concert = model
            });
        }

        #endregion

        #region Update

        [HttpGet]
        [Authorize(Roles.Administrator)]
        public async Task<IActionResult> Edit(int id)
        {
            try
            {
                var model = await this.concertService.GetConcertByIdAsync(id);

                return View(new ConcertViewModel
                {
                    Concert = model
                });
            }
            catch (Exception ex)
            {
                logger.LogError(ex, $"Unable to retrieve concertId: {id}");
                return View();
            }
        }

        [HttpPost]
        [Authorize(Roles.Administrator)]
        public async Task<IActionResult> Edit([Bind(Prefix = "Concert")] Concert model)
        {
            if (ModelState.IsValid)
            {
                try
                {
                    model.UpdatedBy = User.Identity?.Name ?? "Unknown";
                    model.UpdatedOn = DateTime.UtcNow;
                    var updateConcertResult = await this.concertService.UpdateConcertAsync(model);
                    if (updateConcertResult.Success)
                    {
                        return RedirectToAction("Details", new { id = model.Id });
                    }

                    ModelState.AddErrorMessages(updateConcertResult.ErrorMessages);
                }
                catch (Exception ex)
                {
                    logger.LogError(ex, "Unhadled exception from ConcertController.Edit(model)");
                    ModelState.AddModelError(string.Empty, "Unable to save concerts. Please try again later.");
                }
            }

            return View(new ConcertViewModel
            {
                Concert = model
            });
        }
        #endregion

        #region Delete

        [HttpGet]
        [Authorize(Roles.Administrator)]
        public async Task<IActionResult> Delete(int id)
        {
            try
            {
                var model = await this.concertService.GetConcertByIdAsync(id);
                return View(model);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, $"Unable to retrieve concertId: {id}");
                return View();
            }
        }

        [HttpPost]
        [Authorize(Roles.Administrator)]
        [ActionName(nameof(Delete))]
        public async Task<IActionResult> DeleteConfirmed(int id)
        {
            try
            {
                var deleteConcertResult = await this.concertService.DeleteConcertAsync(id);

                if (deleteConcertResult.Success)
                {
                    return RedirectToAction("Index");
                }

                var model = await this.concertService.GetConcertByIdAsync(id);
                ModelState.AddErrorMessages(deleteConcertResult.ErrorMessages);
                return View(nameof(Delete), model);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Unhadled exception from ConcertController.DeleteConfirmed");
                return RedirectToAction("Index");
            }
        }

        #endregion

        #region Details

        public async Task<IActionResult> Details(int id)
        {
            try
            {
                var model = await this.concertService.GetConcertByIdAsync(id);
                if (model == null)
                {
                    return NotFound();
                }
                else if (!User.IsInRole(Roles.Administrator) && !model.IsVisible)
                {
                    // user is not authorized to see a hidden concert
                    return RedirectToAction("Index");
                }

                return View(model);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, $"Unable to retrieve concertId: {id}");
                return View();
            }
        }

        #endregion

        #region Search

        public async Task<IActionResult> Search(SearchRequest request)
        {
            try
            {
                if (string.IsNullOrEmpty(request.Query))
                {
                    ViewBag.NoSearch = "Use the search bar to find your favorite concerts.";
                    return View();
                }

                var result = await this.concertSearchService.SearchAsync(request);
                return View(result);
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, $"Unable to display search results for query '{request.Query}'");
                return View(default(SearchResponse<Concert>));
            }
        }

        #endregion

        #region Suggest

        public async Task<JsonResult> Suggest(string query)
        {
            try
            {
                var suggestions = await this.concertSearchService.SuggestAsync(query);
                return Json(suggestions);
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, $"Unable to suggest search results for query '{query}'");
                return Json(new string[0]);
            }
        }

        #endregion
    }
}