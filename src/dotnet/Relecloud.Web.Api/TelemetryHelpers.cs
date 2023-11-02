using Microsoft.Extensions.Primitives;
using System.Net.Http.Headers;
using System.Linq;
using Azure.Core;
using Relecloud.Web.Models;
using System.Text.Json;

namespace Relecloud.Web.Api
{
    public static class TelemetryHelpers
    {
        public static string ExtractHttpHeader(this HttpRequest request, string customHeader)
        {
            string headerValue = null;
            IHeaderDictionary headers = request.Headers;
            if(request.Headers.TryGetValue(customHeader, out StringValues headerValues)) 
            {
                headerValue = headerValues.FirstOrDefault();
            }
            return headerValue;
        }

        public static OperationBreadcrumb ExtractOperationBreadcrumb(this HttpRequest request, string status, string name)
        {
            var sessionId = ExtractHttpHeader(request, "AZREF_SESSION_ID");
            var requestId = ExtractHttpHeader(request, "AZREF_REQUEST_ID");
            return OperationBreadcrumb.Create(sessionId, requestId, status, name);
        }

        public static string Serialize(this OperationBreadcrumb operationBreadcrumb)
        {
            return JsonSerializer.Serialize(operationBreadcrumb);
        }
    }
}
