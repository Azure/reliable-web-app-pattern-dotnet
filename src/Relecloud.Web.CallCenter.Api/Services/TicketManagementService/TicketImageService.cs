using Azure.Identity;
using Azure.Storage.Blobs;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public class TicketImageService : ITicketImageService
    {
        private readonly IConfiguration configuration;
        private readonly ILogger<TicketImageService> logger;
        public TicketImageService(IConfiguration configuration, ILogger<TicketImageService> logger)
        {
            this.configuration = configuration;
            this.logger = logger;
        }

        public Task<Stream> GetTicketImagesAsync(string imageName)
        {
            try
            {
                var storageUrl = configuration["App:StorageAccount:Uri"];
                var storageContainer = configuration["App:StorageAccount:Container"];
                Uri blobUri = new($"{storageUrl}/{storageContainer}/{imageName}");

                BlobClient blobClient = new(blobUri, new DefaultAzureCredential());
                return blobClient.OpenReadAsync();
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, $"Unable to retrieve image {imageName}");
                return Task.FromResult(Stream.Null);
            }
        }
    }
}