namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public interface ITicketImageService
    {
        Task<Stream> GetTicketImagesAsync(string imageName);
    }
}