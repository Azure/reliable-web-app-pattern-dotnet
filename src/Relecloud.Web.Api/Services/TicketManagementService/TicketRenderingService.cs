using Azure.Identity;
using Azure.Storage.Blobs;

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
            var ticketBlobName = await SaveImageAsync(ticket, ticketImageBlob);
            await UpdateTicketWithBlobNameAsync(ticket, ticketBlobName);
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

        private async Task<string> SaveImageAsync(Ticket ticket, MemoryStream ticketImageBlob)
        {
            var storageUrl = configuration["App:StorageAccount:Url"];
            var storageContainer = configuration["App:StorageAccount:Container"];
            var blobName = BlobNameFormatString.Replace("{EntityId}", ticket.Id.ToString());
            Uri blobUri = new($"{storageUrl}/{storageContainer}/{blobName}");

            BlobClient blobClient = new(blobUri, new DefaultAzureCredential());

            await blobClient.UploadAsync(ticketImageBlob, overwrite: true);

            logger.LogInformation("Successfully wrote blob to storage.");
            return blobName;
        }

        private async Task UpdateTicketWithBlobNameAsync(Ticket ticket, string blobName)
        {
            ticket.ImageName = blobName;
            database.Update(ticket);
            await database.SaveChangesAsync();
        }
    }
}
