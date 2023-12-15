namespace Relecloud.Web.CallCenter.Api.Infrastructure;

using System.Net;

/*
NOTICE: This class is not intended for production scenarios.

This middleware feature is included to demonstrate the Retry and
Circuit Breaker patterns that are discussed in the guide.

Adding this feature to a production web app may cause stability issues.
*/
public class IntermittentErrorRequestMiddleware
{
    private readonly RequestDelegate _next;
    private static int _requestCount = 0;
    private static int _backToBackExceptionCount = -1;

    public IntermittentErrorRequestMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        if (_backToBackExceptionCount == -1)
        {
            LoadConfiguration(context);
        }

        if (_backToBackExceptionCount > 0 && ++_requestCount % (_backToBackExceptionCount + 1) > 0)
        {
            // When enabled this simulation demonstrates the retry pattern
            await ReturnErrorResponse(context);
            return;
        }

        await _next(context);
    }

    private static void LoadConfiguration(HttpContext context)
    {
        var config = context.RequestServices.GetService<IConfiguration>();
        if (config != null)
        {
            if (!string.IsNullOrEmpty(config["Api:App:RetryDemo"]))
            {
                if (int.TryParse(config["Api:App:RetryDemo"], out int newErrorRate))
                {
                    // When set to 1 this simulation will return an error every other request
                    // When set to 2 this simulation will return two errors between successful requests
                    _backToBackExceptionCount = newErrorRate;
                }
            }
        }
    }

    private Task ReturnErrorResponse(HttpContext context)
    {
        context.Response.ContentType = "application/json";
        context.Response.StatusCode = (int)HttpStatusCode.ServiceUnavailable;

        return Task.CompletedTask;
    }
}

public static class IntermittentErrorRequestMiddlewareExtensions
{
    public static IApplicationBuilder UseIntermittentErrorRequestMiddleware(
        this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<IntermittentErrorRequestMiddleware>();
    }
}
