using Microsoft.Extensions.Options;
using Microsoft.Identity.Web;

using System.Net.Http.Headers;

namespace Relecloud.Web.CallCenter.Services.RelecloudApiServices;

public class RelecloudApiTicketImageService : ITicketImageService
{
    private readonly HttpClient httpClient;
    private readonly IHttpContextAccessor httpContextAccessor;
    private readonly ITokenAcquisition tokenAcquisition;
    private readonly IOptions<RelecloudApiOptions> options;

    public RelecloudApiTicketImageService(IHttpContextAccessor httpContextAccessor, HttpClient httpClient, ITokenAcquisition tokenAcquisition, IOptions<RelecloudApiOptions> options)
    {
        this.httpContextAccessor = httpContextAccessor;
        this.httpClient = httpClient;
        this.tokenAcquisition = tokenAcquisition;
        this.options = options;
    }

    public async Task<Stream> GetTicketImagesAsync(string imageName)
    {
        await PrepareAuthenticatedClient();
        var httpRequestMessage = new HttpRequestMessage(HttpMethod.Get, $"api/Image/{imageName}");
        var httpResponseMessage = await httpClient.SendAsync(httpRequestMessage);


        var responseMessage = await httpResponseMessage.Content.ReadAsStreamAsync();

        return responseMessage;
    }


    private async Task PrepareAuthenticatedClient()
    {
        if (httpContextAccessor.HttpContext?.User?.Identity != null)
        {
            var scopes = new[] { options.Value.AttendeeScope ?? throw new ArgumentNullException(nameof(options.Value.AttendeeScope)) };
            var accessToken = await tokenAcquisition.GetAccessTokenForUserAsync(scopes);
            httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
            httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        }
    }
}