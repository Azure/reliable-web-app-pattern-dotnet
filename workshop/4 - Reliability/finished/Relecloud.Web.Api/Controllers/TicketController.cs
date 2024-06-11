using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Relecloud.Web.Api.Services;
using Relecloud.Web.Api.Services.PaymentGatewayService;
using Relecloud.Web.Api.Services.TicketManagementService;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Services;
using Relecloud.Web.Models.TicketManagement;
using System.Net.Mime;

namespace Relecloud.Web.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class TicketController : ControllerBase
    {
        public const int DefaultNumberOfTickets = 5;

        private readonly ILogger<TicketController> logger;

        private readonly IConcertRepository concertRepository;
        private readonly IPaymentGatewayService paymentGatewayService;
        private readonly ITicketManagementService ticketService;

        public TicketController(ILogger<TicketController> logger, IConcertRepository concertRepository, ITicketManagementService ticketService, IPaymentGatewayService paymentGatewayService)
        {
            this.logger = logger;
            this.concertRepository = concertRepository;
            this.ticketService = ticketService;
            this.paymentGatewayService = paymentGatewayService;
        }

        [HttpGet("{id}", Name = "GetTicketById")]
        [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(Ticket))]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [Authorize]
        public async Task<IActionResult> GetAsync(int id)
        {
            try
            {
                var ticket = await this.concertRepository.GetTicketByIdAsync(id);

                if (ticket == null)
                {
                    return NotFound();
                }

                return Ok(ticket);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Unhandled exception from TicketController.GetAsync");
                return Problem("Unable to GetAsync this ticket");
            }
        }

        [HttpGet("ForUser/{userId}", Name = "GetAllTickets")]
        [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(PagedResult<Concert>))]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [Authorize]
        public async Task<IActionResult> GetAllTicketsAsync(string userId, int skip = 0, int take = DefaultNumberOfTickets)
        {
            try
            {
                var tickets = await this.concertRepository.GetAllTicketsAsync(userId, skip, take);

                return Ok(tickets);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Unhandled exception from TicketController.GetAllTicketsAsync");
                return Problem("Unable to GetAllTickets for this user");
            }
        }


        [HttpPost("Purchase", Name = "Purchase")]
        [Consumes(MediaTypeNames.Application.Json)]
        [ProducesResponseType(StatusCodes.Status202Accepted)]
        [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(PurchaseTicketsResult))]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        [Authorize]
        public async Task<IActionResult> PurchaseTicketsAsync(PurchaseTicketsRequest purchaseTicketRequest)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    return BadRequest();
                }

                var errors = new List<string>();
                if (purchaseTicketRequest.PaymentDetails == null)
                {
                    errors.Add("Missing required payment details");
                }
                if (purchaseTicketRequest.ConcertIdsAndTicketCounts == null)
                {
                    errors.Add("Missing required concert ticket details");
                }
                if (string.IsNullOrEmpty(purchaseTicketRequest.UserId))
                {
                    errors.Add("Missing required userId");
                }
                if (errors.Any())
                {
                    return BadRequest(PurchaseTicketsResult.ErrorResponse(errors));
                }

                var orderTotal = await TotalInvoiceAmountAsync(purchaseTicketRequest);
                var preAuthRequest = new PreAuthPaymentRequest
                {
                    Amount = orderTotal,
                    PaymentDetails = purchaseTicketRequest.PaymentDetails!,
                    Tickets = purchaseTicketRequest.ConcertIdsAndTicketCounts
                };
                var preAuthResponse = await paymentGatewayService.PreAuthPaymentAsync(preAuthRequest);

                if (preAuthResponse.Status != PreAuthPaymentResultStatus.FundsOnHold)
                {
                    return BadRequest(PurchaseTicketsResult.ErrorResponse("We were unable to process this card. Please review your payment details."));
                }

                #pragma warning disable CS8602 // Dereference of a possibly null reference.
                //null chec handled by error messages above
                var customer = await this.concertRepository.GetCustomerByEmailAsync(purchaseTicketRequest.PaymentDetails.Email);
                #pragma warning restore CS8602 // Dereference of a possibly null reference.

                var customerId = customer?.Id ?? 0;
                if (customerId == 0)
                {
                    var createResult = await this.concertRepository.CreateCustomerAsync(new Customer
                    {
                        Name = purchaseTicketRequest.PaymentDetails.Name,
                        Email = purchaseTicketRequest.PaymentDetails.Email,
                        Phone = purchaseTicketRequest.PaymentDetails.Phone,
                    });
                    if (createResult.Success)
                    {
                        customerId = createResult.NewId;
                    }
                }

                foreach (var concertAndTickets in purchaseTicketRequest.ConcertIdsAndTicketCounts!)
                {
                    var reserveResult = await this.ticketService.ReserveTicketsAsync(concertAndTickets.Key, purchaseTicketRequest.UserId!, concertAndTickets.Value, customerId);

                    if (reserveResult.Status != ReserveTicketsResultStatus.Success)
                    {
                        return BadRequest(PurchaseTicketsResult.ErrorResponse($"{reserveResult.Status}: Tickets not successfully reserved"));
                    }
                }

                //built-in assumption: if generating a ticket throws an error then we should not reach this code
                // and the hold on the customer's card will automatically be released by the Payment Gateway
                var captureRequest = new CapturePaymentRequest
                {
                    HoldCode = preAuthResponse.HoldCode,
                    TotalPrice = orderTotal
                };

                await paymentGatewayService.CapturePaymentAsync(captureRequest);

                return Accepted(new PurchaseTicketsResult
                {
                    Status = PurchaseTicketsResultStatus.Success
                });
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Unhandled exception from TicketController.PurchaseTicketsAsync");
                return Problem("Unable to Create the ticket");
            }
        }

        private async Task<double> TotalInvoiceAmountAsync(PurchaseTicketsRequest request)
        {
            if (request == null || request.ConcertIdsAndTicketCounts == null)
            {
                return 0;
            }

            double totalAmount = 0.0;
            foreach (var concertId in request.ConcertIdsAndTicketCounts.Keys)
            {
                var concert = await this.concertRepository.GetConcertByIdAsync(concertId);
                if (concert is null)
                {
                    throw new InvalidOperationException("Concert Not Found");
                }
                totalAmount += concert.Price * request.ConcertIdsAndTicketCounts[concertId];
            }

            return totalAmount;
        }
    }
}
