using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Attributes;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Enums;
using Microsoft.Extensions.Logging;
using Microsoft.OpenApi.Models;
using Newtonsoft.Json;
using Relecloud.Mocks.PaymentGateway.Models;
using System.IO;
using System.Net;
using System.Threading.Tasks;

namespace Relecloud.Mocks.PaymentGateway
{
    public class PreAuthFunction
    {
        private readonly ILogger<PreAuthFunction> _logger;

        public PreAuthFunction(ILogger<PreAuthFunction> log)
        {
            _logger = log;
        }

        [FunctionName("PreAuth")]
        [OpenApiOperation(operationId: "PreAuthPayment")]
        [OpenApiSecurity("function_key", SecuritySchemeType.ApiKey, Name = "code", In = OpenApiSecurityLocationType.Query)]
        [OpenApiRequestBody(contentType: "application/json", bodyType: typeof(PreAuthPaymentOptions), Description = "Parameters", Required = true)]
        [OpenApiResponseWithBody(statusCode: HttpStatusCode.OK, contentType: "application/json", bodyType: typeof(PreAuthPaymentResult), Description = "The status of the operation")]
        public async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "post", Route = null)] HttpRequest req)
        {
            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            var data = JsonConvert.DeserializeObject<PreAuthPaymentOptions>(requestBody);

            if (data == null || data.PaymentDetails == null)
            {
                return new OkObjectResult(new PreAuthPaymentResult
                {
                    HoldCode = string.Empty,
                    Status = PreAuthPaymentStatuses.InsufficientFunds
                });
            }

            _logger.LogInformation("C# HTTP trigger function processed a request.");

            return new OkObjectResult(new PreAuthPaymentResult
            {
                HoldCode = RandomCodeGenerator.GenerateRandomCode(),
                Status = PreAuthPaymentStatuses.FundsOnHold
            });
        }
    }
}

