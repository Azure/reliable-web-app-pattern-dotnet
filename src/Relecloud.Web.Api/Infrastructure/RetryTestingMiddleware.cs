using System.Net;
using System.Security.Claims;

namespace Relecloud.Web.Api.Infrastructure
{
    public class RetryTestingMiddleware
    {
        private readonly RequestDelegate _next;
        private int _requestCount = 0;

        public RetryTestingMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var config = context.RequestServices.GetService<IConfiguration>();
            if (config != null)
            {
                if (!string.IsNullOrEmpty(config["Api:App:RetryDemo"]))
                {
                    int errorRate = 2;
                    if (int.TryParse(config["Api:App:RetryDemo"], out int newErrorRate))
                    {
                        //by default this middleware throws an error every-other time
                        //we can use the config to override this and change the frequency
                        errorRate = newErrorRate;
                    }
                    if (_requestCount++ % errorRate == 0)
                    {
                        // When enabled this simulation demonstrates the retry pattern
                        await ReturnErrorResponse(context);
                    }
                }
            }

            await _next(context);
        }

        private Task ReturnErrorResponse(HttpContext context)
        {
            context.Response.ContentType = "application/json";
            context.Response.StatusCode = (int)HttpStatusCode.ServiceUnavailable;

            return Task.CompletedTask;
        }
    }

    public static class RetryTestingMiddlewareExtensions
    {
        public static IApplicationBuilder UseRetryTestingMiddleware(
            this IApplicationBuilder builder)
        {
            return builder.UseMiddleware<RetryTestingMiddleware>();
        }
    }
}