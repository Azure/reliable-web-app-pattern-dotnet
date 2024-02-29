using Microsoft.Extensions.Options;
using Microsoft.Identity.Web;
using Relecloud.Web.CallCenter.Infrastructure;
using Relecloud.Web.Models.TicketManagement;
using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

namespace Relecloud.Web.CallCenter.Services.RelecloudApiServices
{
    public class RelecloudApiTicketPurchaseService : ITicketPurchaseService
    {
        private readonly HttpClient httpClient;
        private readonly IHttpContextAccessor httpContextAccessor;
        private readonly ITokenAcquisition tokenAcquisition;
        private readonly IOptions<RelecloudApiOptions> options;

        public RelecloudApiTicketPurchaseService(IHttpContextAccessor httpContextAccessor, HttpClient httpClient, ITokenAcquisition tokenAcquisition, IOptions<RelecloudApiOptions> options)
        {
            this.httpContextAccessor = httpContextAccessor;
            this.httpClient = httpClient;
            this.tokenAcquisition = tokenAcquisition;
            this.options = options;
        }

        public async Task<PurchaseTicketsResult> PurchaseTicketAsync(PurchaseTicketsRequest request)
        {
            await PrepareAuthenticatedClient();
            var httpRequestMessage = new HttpRequestMessage(HttpMethod.Post, "api/Ticket/Purchase");

            httpRequestMessage.Content = JsonContent.Create(request);
            var httpResponseMessage = await this.httpClient.SendAsync(httpRequestMessage);
            var responseMessage = await httpResponseMessage.Content.ReadAsStringAsync();

            if (httpResponseMessage.StatusCode != HttpStatusCode.Accepted)
            {
                throw new InvalidOperationException(nameof(PurchaseTicketAsync), new WebException(responseMessage));
            }

            return JsonSerializer.Deserialize<PurchaseTicketsResult>(responseMessage, RelecloudApiConfiguration.GetSerializerOptions())
                ?? new PurchaseTicketsResult();
        }

        private async Task PrepareAuthenticatedClient()
        {
            if (this.httpContextAccessor.HttpContext?.User?.Identity != null)
            {
                var scopes = new[] { this.options.Value.AttendeeScope ?? throw new ArgumentNullException(nameof(this.options.Value.AttendeeScope)) };
                var accessToken = await this.tokenAcquisition.GetAccessTokenForUserAsync(scopes);
                this.httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
                this.httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            }
        }
    }
}
