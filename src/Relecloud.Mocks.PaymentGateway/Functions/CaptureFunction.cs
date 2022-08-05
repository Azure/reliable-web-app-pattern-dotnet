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

namespace Relecloud.Mocks.PaymentGateway.Functions
{
    public class CaptureFunction
    {
        private readonly ILogger<CaptureFunction> _logger;

        public CaptureFunction(ILogger<CaptureFunction> log)
        {
            _logger = log;
        }

        private static int ErrorGenerator = 0;

        [FunctionName("CaptureFunction")]
        [OpenApiOperation(operationId: "CapturePayment")]
        [OpenApiSecurity("function_key", SecuritySchemeType.ApiKey, Name = "code", In = OpenApiSecurityLocationType.Query)]
        [OpenApiRequestBody(contentType: "application/json", bodyType: typeof(CapturePaymentOptions), Description = "Parameters", Required = true)]
        [OpenApiResponseWithBody(statusCode: HttpStatusCode.OK, contentType: "application/json", bodyType: typeof(CapturePaymentResult), Description = "The status of the operation")]
        public async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "post", Route = null)] HttpRequest req)
        {
            #if DEBUG
            //enables Devs to test retry logic
            if (ErrorGenerator++ % 2 == 0)
            {
                return new BadRequestObjectResult("Nope");
            }
            #endif

            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            var data = JsonConvert.DeserializeObject<CapturePaymentResult>(requestBody);

            _logger.LogInformation("C# HTTP trigger function processed a request.");

            return new OkObjectResult(new CapturePaymentResult
            {
                ConfirmationNumber = RandomCodeGenerator.GenerateRandomCode(),
                Status = CapturePaymentStatuses.CaptureSuccessful
            });
        }
    }
}

