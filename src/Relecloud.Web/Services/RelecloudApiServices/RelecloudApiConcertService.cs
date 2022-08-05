using Microsoft.Extensions.Options;
using Microsoft.Identity.Web;
using Relecloud.Web.Infrastructure;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Services;
using Relecloud.Web.Services.RelecloudApiServices;
using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

namespace Relecloud.Web.Services.ApiConcertService
{
    public class RelecloudApiConcertService : IConcertContextService
    {
        private readonly IHttpContextAccessor httpContextAccessor;
        private readonly HttpClient httpClient;
        private readonly ITokenAcquisition tokenAcquisition;
        private readonly IOptions<RelecloudApiOptions> options;

        public RelecloudApiConcertService(IHttpContextAccessor httpContextAccessor, HttpClient httpClient, ITokenAcquisition tokenAcquisition, IOptions<RelecloudApiOptions> options)
        {
            this.httpContextAccessor = httpContextAccessor;
            this.httpClient = httpClient;
            this.tokenAcquisition = tokenAcquisition;
            this.options = options;
        }

        public async Task<CreateResult> CreateConcertAsync(Concert newConcert)
        {
            await PrepareAuthenticatedClient();
            var httpRequestMessage = new HttpRequestMessage(HttpMethod.Post, "api/Concert");
            httpRequestMessage.Content = JsonContent.Create(newConcert);
            
            var httpResponseMessage = await this.httpClient.SendAsync(httpRequestMessage);
            var responseMessage = await httpResponseMessage.Content.ReadAsStringAsync();

            if (httpResponseMessage.StatusCode == HttpStatusCode.BadRequest)
            {
                var failedCreateOperation = JsonSerializer.Deserialize<CreateResult>(responseMessage, RelecloudApiConfiguration.GetSerializerOptions());
                return failedCreateOperation ?? throw new InvalidOperationException("Failed to parse response");
            }
            else if (httpResponseMessage.StatusCode != HttpStatusCode.Created)
            {
                throw new InvalidOperationException(nameof(CreateConcertAsync), new WebException(responseMessage));
            }

            var returnedConcert = JsonSerializer.Deserialize<Concert>(responseMessage, RelecloudApiConfiguration.GetSerializerOptions());

            if (returnedConcert == null)
            {
                throw new InvalidOperationException("Concert was not created successfully");
            }

            return new CreateResult
            {
                Success = true,
                NewId = returnedConcert.Id
            };
        }

        public async Task<UpdateResult> CreateOrUpdateUserAsync(User user)
        {
            await PrepareAuthenticatedClient();
            var httpRequestMessage = new HttpRequestMessage(HttpMethod.Patch, "api/User");
            httpRequestMessage.Content = JsonContent.Create(user);
            var httpResponseMessage = await this.httpClient.SendAsync(httpRequestMessage);

            if (httpResponseMessage.StatusCode == HttpStatusCode.BadRequest)
            {
                var responseMessage = await httpResponseMessage.Content.ReadAsStringAsync();
                var failedCreateOperation = JsonSerializer.Deserialize<CreateResult>(responseMessage, RelecloudApiConfiguration.GetSerializerOptions());
                return failedCreateOperation ?? throw new InvalidOperationException("Failed to parse response");
            }
            else if (httpResponseMessage.StatusCode != HttpStatusCode.Accepted)
            {
                throw new InvalidOperationException(nameof(CreateOrUpdateUserAsync), new WebException(await httpResponseMessage.Content.ReadAsStringAsync()));
            }

            return new UpdateResult
            {
                Success = true,
            };
        }

        public async Task<DeleteResult> DeleteConcertAsync(int id)
        {
            await PrepareAuthenticatedClient();
            var httpRequestMessage = new HttpRequestMessage(HttpMethod.Delete, $"api/Concert/{id}");
            var httpResponseMessage = await this.httpClient.SendAsync(httpRequestMessage);

            if (httpResponseMessage.StatusCode == HttpStatusCode.BadRequest)
            {
                var responseMessage = await httpResponseMessage.Content.ReadAsStringAsync();
                var failedCreateOperation = JsonSerializer.Deserialize<DeleteResult>(responseMessage, RelecloudApiConfiguration.GetSerializerOptions());
                return failedCreateOperation ?? throw new InvalidOperationException("Failed to parse response");
            }
            else if (httpResponseMessage.StatusCode != HttpStatusCode.OK)
            {
                throw new InvalidOperationException(nameof(DeleteConcertAsync), new WebException(await httpResponseMessage.Content.ReadAsStringAsync()));
            }

            return new DeleteResult
            {
                Success = true
            };
        }

        public async Task<PagedResult<Ticket>> GetAllTicketsAsync(string userId, int skip, int take)
        {
            await PrepareAuthenticatedClient();
            var httpRequestMessage = new HttpRequestMessage(HttpMethod.Get, $"api/Ticket/ForUser/{userId}?skip={skip}&take={take}");
            var httpResponseMessage = await this.httpClient.SendAsync(httpRequestMessage);
            var responseMessage = await httpResponseMessage.Content.ReadAsStringAsync();

            if (httpResponseMessage.StatusCode != HttpStatusCode.OK)
            {
                throw new InvalidOperationException(nameof(GetAllTicketsAsync), new WebException(responseMessage));
            }

            return JsonSerializer.Deserialize<PagedResult<Ticket>>(responseMessage, RelecloudApiConfiguration.GetSerializerOptions())
                ?? new PagedResult<Ticket>(Array.Empty<Ticket>(), 0);
        }

        public async Task<Concert?> GetConcertByIdAsync(int id)
        {
            await PrepareAuthenticatedClient();
            var httpRequestMessage = new HttpRequestMessage(HttpMethod.Get, $"api/Concert/{id}");
            var httpResponseMessage = await this.httpClient.SendAsync(httpRequestMessage);
            var responseMessage = await httpResponseMessage.Content.ReadAsStringAsync();

            if (httpResponseMessage.StatusCode != HttpStatusCode.OK)
            {
                throw new InvalidOperationException(nameof(GetConcertByIdAsync), new WebException(responseMessage));
            }

            return JsonSerializer.Deserialize<Concert>(responseMessage, RelecloudApiConfiguration.GetSerializerOptions());
        }

        public async Task<ICollection<Concert>> GetConcertsByIdAsync(ICollection<int> ids)
        {
            await PrepareAuthenticatedClient();
            var listOfIds = JsonSerializer.Serialize(ids);
            var httpRequestMessage = new HttpRequestMessage(HttpMethod.Get, $"api/Concert/GetConcertsByIds?listOfIds={listOfIds}");
            var httpResponseMessage = await this.httpClient.SendAsync(httpRequestMessage);
            var responseMessage = await httpResponseMessage.Content.ReadAsStringAsync();

            if (httpResponseMessage.StatusCode != HttpStatusCode.OK)
            {
                throw new InvalidOperationException(nameof(GetConcertsByIdAsync), new WebException(responseMessage));
            }

            return JsonSerializer.Deserialize<List<Concert>>(responseMessage, RelecloudApiConfiguration.GetSerializerOptions()) ?? new List<Concert>();
        }

        public async Task<Ticket?> GetTicketByIdAsync(int id)
        {
            await PrepareAuthenticatedClient();
            var httpRequestMessage = new HttpRequestMessage(HttpMethod.Get, $"api/Ticket/{id}");
            var httpResponseMessage = await this.httpClient.SendAsync(httpRequestMessage);
            var responseMessage = await httpResponseMessage.Content.ReadAsStringAsync();

            if (httpResponseMessage.StatusCode != HttpStatusCode.OK)
            {
                throw new InvalidOperationException(nameof(GetTicketByIdAsync), new WebException(responseMessage));
            }

            return JsonSerializer.Deserialize<Ticket>(responseMessage, RelecloudApiConfiguration.GetSerializerOptions());
        }

        public async Task<ICollection<Concert>> GetUpcomingConcertsAsync(int count)
        {
            await PrepareAuthenticatedClient();
            var httpRequestMessage = new HttpRequestMessage(HttpMethod.Get, "api/Concert/GetUpcomingConcerts");
            var httpResponseMessage = await this.httpClient.SendAsync(httpRequestMessage);
            var responseMessage = await httpResponseMessage.Content.ReadAsStringAsync();

            if (httpResponseMessage.StatusCode != HttpStatusCode.OK)
            {
                throw new InvalidOperationException(nameof(GetUpcomingConcertsAsync), new WebException(responseMessage));
            }

            return JsonSerializer.Deserialize<List<Concert>>(responseMessage, RelecloudApiConfiguration.GetSerializerOptions()) ?? new List<Concert>();
        }

        public async Task<User?> GetUserByIdAsync(string id)
        {
            await PrepareAuthenticatedClient();
            var httpRequestMessage = new HttpRequestMessage(HttpMethod.Get, $"api/User/{id}");
            var httpResponseMessage = await this.httpClient.SendAsync(httpRequestMessage);
            var responseMessage = await httpResponseMessage.Content.ReadAsStringAsync();

            if (httpResponseMessage.StatusCode != HttpStatusCode.OK)
            {
                throw new InvalidOperationException(nameof(GetUserByIdAsync), new WebException(responseMessage));
            }

            return JsonSerializer.Deserialize<User>(responseMessage, RelecloudApiConfiguration.GetSerializerOptions());
        }

        public async Task<UpdateResult> UpdateConcertAsync(Concert model)
        {
            await PrepareAuthenticatedClient();
            var httpRequestMessage = new HttpRequestMessage(HttpMethod.Put, "api/Concert");
            httpRequestMessage.Content = JsonContent.Create(model);
            var httpResponseMessage = await this.httpClient.SendAsync(httpRequestMessage);

            if (httpResponseMessage.StatusCode == HttpStatusCode.BadRequest)
            {
                var responseMessage = await httpResponseMessage.Content.ReadAsStringAsync();
                var failedCreateOperation = JsonSerializer.Deserialize<CreateResult>(responseMessage, RelecloudApiConfiguration.GetSerializerOptions());
                return failedCreateOperation ?? throw new InvalidOperationException("Failed to parse response");
            }
            else if (httpResponseMessage.StatusCode != HttpStatusCode.Accepted)
            {
                throw new InvalidOperationException(nameof(UpdateConcertAsync), new WebException(await httpResponseMessage.Content.ReadAsStringAsync()));
            }

            return new UpdateResult
            {
                Success = true,
            };
        }

        private async Task PrepareAuthenticatedClient()
        {
            var identity = this.httpContextAccessor.HttpContext?.User?.Identity;
            if (identity != null && identity.IsAuthenticated)
            {
                var scopes = new[] { this.options.Value.AttendeeScope };
                var accessToken = await this.tokenAcquisition.GetAccessTokenForUserAsync(scopes);
                this.httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
                this.httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            }
        }
    }
}
