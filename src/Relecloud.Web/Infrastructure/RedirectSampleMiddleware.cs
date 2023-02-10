/*
NOTICE: This class is not intended for production scenarios.

This middleware feature is included to help readers try the sample.
When a user visits the app service directly we will redirect to
Azure Front Door which is registered with Azure AD.
In a prod scenario we recommend using Access Restrictions
to ensure the Front Door cannot be bypassed which would show an error page.

Note that we also recommend host name preservation which
means that end users would never see the azure web app url, or the azure front door url
https://learn.microsoft.com/en-us/azure/architecture/best-practices/host-name-preservation
*/
using Microsoft.AspNetCore.Http;

namespace Relecloud.Web.Infrastructure
{
    public class RedirectSampleMiddleware
    {
        private readonly RequestDelegate _next;

        public RedirectSampleMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var config = context.RequestServices.GetService<IConfiguration>();
            if (config != null && !string.IsNullOrEmpty(config["App:FrontDoorUri"]))
            {
                var hostUri = context.Request.GetTypedHeaders().Host.ToString();
                var frontDoorUri = config["App:FrontDoorUri"];
                
                if (hostUri != frontDoorUri)
                {
                    // the forwarded host header should be populated by Front Door
                    // block this attempt to access the web app directly by redirecting to Front Door
                    context.Response.Redirect($"https://{frontDoorUri}");
                    return;
                }
            }

            await _next(context);
        }
    }

    public static class RedirectSampleMiddlewareExtensions
    {
        public static IApplicationBuilder UseRetryTestingMiddleware(
            this IApplicationBuilder builder)
        {
            return builder.UseMiddleware<RedirectSampleMiddleware>();
        }
    }
}
