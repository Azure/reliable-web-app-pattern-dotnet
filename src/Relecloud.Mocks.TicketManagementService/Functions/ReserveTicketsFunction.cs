using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Attributes;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Enums;
using Microsoft.Extensions.Logging;
using Microsoft.OpenApi.Models;
using Relecloud.Web.Api.Services.TicketManagementService;
using Relecloud.Web.Models.TicketManagement;
using System;
using System.Collections.Generic;
using System.Net;
using System.Threading.Tasks;

namespace Relecloud.Mocks.TicketManagementService.Functions
{
    public class ReserveTicketsFunction
    {
        private readonly ILogger<ReserveTicketsFunction> _logger;
        private TicketNumberGenerator _ticketNumberGenerator;

        public ReserveTicketsFunction(ILogger<ReserveTicketsFunction> log)
        {
            _logger = log;
            _ticketNumberGenerator = new TicketNumberGenerator();
        }

        [FunctionName("ReserveTicketsFunction")]
        [OpenApiOperation(operationId: "ReserveTickets", tags: new[] { "TicketManagementServices" })]
        [OpenApiSecurity("function_key", SecuritySchemeType.ApiKey, Name = "code", In = OpenApiSecurityLocationType.Query)]
        [OpenApiParameter(name: "concertId", In = ParameterLocation.Query, Required = true, Type = typeof(string), Description = "A uniqueIdentifier for a Concert")]
        [OpenApiParameter(name: "userId", In = ParameterLocation.Query, Required = true, Type = typeof(string), Description = "A uniqueIdentifier for a User")]
        [OpenApiParameter(name: "ticketCount", In = ParameterLocation.Query, Required = true, Type = typeof(int), Description = "Number of tickets to reserve")]
        [OpenApiResponseWithBody(statusCode: HttpStatusCode.OK, contentType: "application/json", bodyType: typeof(ReserveTicketsResult), Description = "The status of the operation")]
        public Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req)
        {
            _logger.LogInformation("C# HTTP trigger ReserveTicketsFunction processed a request.");

            string concertId = req.Query["concertId"];
            string ticketCountStr = req.Query["ticketCount"];
            int ticketCount = 0;
            if (!int.TryParse(ticketCountStr, out ticketCount))
            {
                _logger.LogError($"Cannot parse ticketCount: {ticketCountStr}");
                throw new ArgumentException(nameof(ticketCount));
            }

            var status = ReserveTicketsResultStatus.ConcertNotFound;

            if (!string.IsNullOrEmpty(concertId))
            {
                if (concertId.EndsWith('1') && concertId.StartsWith('1'))
                {
                    status = ReserveTicketsResultStatus.Success;
                }
                else if (concertId.EndsWith('1'))
                {
                    status = ReserveTicketsResultStatus.NotEnoughTicketsRemaining;
                }
                else
                {
                    status = ReserveTicketsResultStatus.ConcertNotFound;
                }
            }

            var ticketNumbers = new List<string>();
            if (status == ReserveTicketsResultStatus.Success)
            {
                for(int i=0; i< ticketCount; i++)
                {
                    var ticketNumber = _ticketNumberGenerator.Generate(25);
                    ticketNumbers.Add(ticketNumber);
                }
            }

            IActionResult response = new OkObjectResult(new ReserveTicketsResult
            {
                Status = status,
                TicketNumbers = ticketNumbers,
                ErrorMessage = status switch
                {
                    ReserveTicketsResultStatus.NotEnoughTicketsRemaining => "Not enough tickets remaining",
                    ReserveTicketsResultStatus.ConcertNotFound => "Concert not found",
                    _ => null
                }
            });

            return Task.FromResult(response);
        }
    }
}

