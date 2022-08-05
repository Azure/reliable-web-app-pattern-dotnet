using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Attributes;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Enums;
using Microsoft.Extensions.Logging;
using Microsoft.OpenApi.Models;
using Relecloud.Web.Models.TicketManagement;
using System.Net;
using System.Threading.Tasks;

namespace Relecloud.Mocks.TicketManagementService.Functions
{
    public class HaveTicketsBeenSoldFunction
    {
        private readonly ILogger<HaveTicketsBeenSoldFunction> _logger;

        public HaveTicketsBeenSoldFunction(ILogger<HaveTicketsBeenSoldFunction> log)
        {
            _logger = log;
        }

        [FunctionName("HaveTicketsBeenSoldFunction")]
        [OpenApiOperation(operationId: "HaveTicketsBeenSold", tags: new[] { "TicketManagementServices" })]
        [OpenApiSecurity("function_key", SecuritySchemeType.ApiKey, Name = "code", In = OpenApiSecurityLocationType.Query)]
        [OpenApiParameter(name: "concertId", In = ParameterLocation.Query, Required = true, Type = typeof(string), Description = "A uniqueIdentifierForAConcert")]
        [OpenApiResponseWithBody(statusCode: HttpStatusCode.OK, contentType: "application/json", bodyType: typeof(HaveTicketsBeenSoldResult), Description = "The status of the operation")]
        public Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = null)] HttpRequest req)
        {
            _logger.LogInformation("C# HTTP trigger HaveTicketsBeenSoldFunction processed a request.");

            string concertId = req.Query["concertId"];
            var haveTicketsBeenSold = false;
            var isConcertIdFound = false;

            if (!string.IsNullOrEmpty(concertId))
            {
                isConcertIdFound = concertId.EndsWith('1');
                haveTicketsBeenSold = isConcertIdFound && concertId.StartsWith('1');
            }

            IActionResult response = new OkObjectResult(new HaveTicketsBeenSoldResult
            {
                HaveTicketsBeenSold = haveTicketsBeenSold,
                ErrorMessage = isConcertIdFound ? string.Empty : "Invalid concertId"
            });

            return Task.FromResult(response);
        }
    }
}

