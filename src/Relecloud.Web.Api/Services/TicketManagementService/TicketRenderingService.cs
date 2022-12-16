using Azure.Storage.Blobs;
using Azure.Storage.Sas;
using Microsoft.EntityFrameworkCore;
using Relecloud.Web.Api.Services.SqlDatabaseConcertRepository;
using Relecloud.Web.Models.ConcertContext;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public class TicketRenderingService : ITicketRenderingService
    {
        private const string StorageContainerName = "tickets";
        private const string BlobNameFormatString = "ticket-{EntityId}.png";

        private readonly IConfiguration configuration;
        private readonly ConcertDataContext database;
        private readonly ILogger<TicketRenderingService> logger;

        public TicketRenderingService(ConcertDataContext database, IConfiguration configuration, ILogger<TicketRenderingService> logger)
        {
            this.configuration = configuration;
            this.database = database;
            this.logger = logger;
        }

        public async Task CreateTicketImageAsync(int ticketId)
        {
            var ticket = this.database.Tickets
                .Include(ticket => ticket.Concert)
                .Include(ticket => ticket.User)
                .Include(ticket => ticket.Customer)
                .Where(ticket => ticket.Id == ticketId).FirstOrDefault();
            if (ticket == null)
            {
                logger.LogWarning($"No Ticket found for id:{ticketId}");
                return;
            }

            var ticketImageBlob = RenderImage(ticket);
            var sasUri = await SaveImageAsync(ticket, ticketImageBlob);
            await UpdateTicketWithUriAsync(ticket, sasUri);
        }

        private MemoryStream RenderImage(Ticket ticket)
        {
            var ticketImageBlob = new MemoryStream();
            if (ticket == null)
            {
                logger.LogWarning("Nothing to render for null ticket");
                return ticketImageBlob;
            }
            if (ticket.Concert == null)
            {
                logger.LogWarning("Cannot find the concert related to this ticket");
                return ticketImageBlob;
            }
            if (ticket.User == null)
            {
                logger.LogWarning("Cannot find the user related to this ticket");
                return ticketImageBlob;
            }
            if (ticket.Customer == null)
            {
                logger.LogWarning("Cannot find the customer related to this ticket");
                return ticketImageBlob;
            }

            using (var headerFont = new Font("Arial", 18, FontStyle.Bold))
            using (var textFont = new Font("Arial", 12, FontStyle.Regular))
            using (var bitmap = new Bitmap(640, 200, PixelFormat.Format24bppRgb))
            using (var graphics = Graphics.FromImage(bitmap))
            {
                graphics.SmoothingMode = SmoothingMode.AntiAlias;
                graphics.Clear(Color.White);

                // Print concert details.
                graphics.DrawString(ticket.Concert.Artist, headerFont, Brushes.DarkSlateBlue, new PointF(10, 10));
                graphics.DrawString($"{ticket.Concert.Location}   |   {ticket.Concert.StartTime.UtcDateTime}", textFont, Brushes.Gray, new PointF(10, 40));
                graphics.DrawString($"{ticket.Customer.Email}   |   {ticket.Concert.Price.ToString("c")}", textFont, Brushes.Gray, new PointF(10, 60));

                // Print a fake barcode.
                var random = new Random();
                var offset = 15;
                while (offset < 620)
                {
                    var width = 2 * random.Next(1, 3);
                    graphics.FillRectangle(Brushes.Black, offset, 90, width, 90);
                    offset += width + (2 * random.Next(1, 3));
                }

                bitmap.Save(ticketImageBlob, ImageFormat.Png);
            }

            ticketImageBlob.Position = 0;
            return ticketImageBlob;
        }

        private async Task<Uri> SaveImageAsync(Ticket ticket, MemoryStream ticketImageBlob)
        {
            var storageAccountConnStr = this.configuration["App:StorageAccount:ConnectionString"];
            var blobServiceClient = new BlobServiceClient(storageAccountConnStr);

            //  Gets a reference to the container.
            var blobContainerClient = blobServiceClient.GetBlobContainerClient(StorageContainerName);

            //  Gets a reference to the blob in the container
            var blobClient = blobContainerClient.GetBlobClient(BlobNameFormatString.Replace("{EntityId}", ticket.Id.ToString()));
            await blobClient.UploadAsync(ticketImageBlob, overwrite: true);

            logger.LogInformation("Successfully wrote blob to storage.");

            //  Defines the resource being accessed and for how long the access is allowed.
            var blobSasBuilder = new BlobSasBuilder
            {
                StartsOn = DateTime.UtcNow.AddMinutes(-5),
                ExpiresOn = DateTime.UtcNow.Add(TimeSpan.FromDays(30)),
            };

            //  Defines the type of permission.
            blobSasBuilder.SetPermissions(BlobSasPermissions.Read);

            //  Builds the Sas URI.
            var queryUri = blobClient.GenerateSasUri(blobSasBuilder);

            return queryUri;
        }

        private async Task UpdateTicketWithUriAsync(Ticket ticket, Uri sasUri)
        {
            ticket.ImageUrl = sasUri.ToString();
            database.Update(ticket);
            await database.SaveChangesAsync();
        }
    }
}
