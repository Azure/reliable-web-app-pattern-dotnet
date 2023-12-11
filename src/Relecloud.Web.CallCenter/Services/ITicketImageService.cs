namespace Relecloud.Web.CallCenter.Services;

public interface ITicketImageService
{
    Task<Stream> GetTicketImagesAsync(string imageName);
}