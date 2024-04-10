// Copyright (c) Microsoft Corporation. All Rights Reserved.
// Licensed under the MIT License.

using Azure.Storage.Blobs;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public class TicketImageService : ITicketImageService
    {
        private readonly ILogger<TicketImageService> logger;
        private readonly BlobContainerClient blobContainerClient;

        public TicketImageService(IConfiguration configuration, BlobServiceClient blobServiceClient, ILogger<TicketImageService> logger)
        {
            this.logger = logger;

            // It is best practice to create Azure SDK clients once and reuse them.
            // https://learn.microsoft.com/azure/storage/blobs/storage-blob-client-management#manage-client-objects
            // https://devblogs.microsoft.com/azure-sdk/lifetime-management-and-thread-safety-guarantees-of-azure-sdk-net-clients/
            this.blobContainerClient = blobServiceClient.GetBlobContainerClient(configuration["App:StorageAccount:Container"]);
        }

        public Task<Stream> GetTicketImagesAsync(string imageName)
        {
            try
            {
                this.logger.LogInformation("Retrieving image {ImageName} from blob storage container {ContainerName}.", imageName, blobContainerClient.Name);
                var blobClient = blobContainerClient.GetBlobClient(imageName);

                return blobClient.OpenReadAsync();
            }
            catch (Exception ex)
            {
                this.logger.LogError(ex, "Unable to retrieve image {ImageName} from blob storage container {ContainerName}", imageName, blobContainerClient.Name);
                return Task.FromResult(Stream.Null);
            }
        }
    }
}
