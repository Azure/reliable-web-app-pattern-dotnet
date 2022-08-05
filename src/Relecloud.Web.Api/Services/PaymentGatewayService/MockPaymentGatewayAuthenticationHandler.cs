namespace Relecloud.Web.Api.Services.PaymentGatewayService
{
    public class MockPaymentGatewayAuthenticationHandler : DelegatingHandler
    {
        private readonly string _escapedKey;

        public MockPaymentGatewayAuthenticationHandler(string key)
        {
            // escape the key since it might contain invalid characters
            _escapedKey = Uri.EscapeDataString(key);
        }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            if (request.RequestUri != null)
            {
                // we'll use the UriBuilder to parse and modify the url
                var uriBuilder = new UriBuilder(request.RequestUri);

                // when the query string is empty, we simply want to set the appid query parameter
                if (string.IsNullOrEmpty(uriBuilder.Query))
                {
                    uriBuilder.Query = $"code={_escapedKey}";
                }
                // otherwise we want to append it
                else
                {
                    uriBuilder.Query = $"{uriBuilder.Query}&code={_escapedKey}";
                }
                // replace the uri in the request object
                request.RequestUri = uriBuilder.Uri;
            }

            // make the request as normal
            return base.SendAsync(request, cancellationToken);
        }
    }
}
