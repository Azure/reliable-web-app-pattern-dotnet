namespace Relecloud.Web.Services.MockServices;

public class MockTicketImageService : ITicketImageService
{
    public Task<Stream> GetTicketImagesAsync(string imageName)
    {
        return Task.FromResult(new MemoryStream() as Stream);
    }
}
