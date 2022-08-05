using Azure.Storage.Blobs;
using Azure.Storage.Sas;
using Microsoft.Azure.WebJobs;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;

namespace Relecloud.FunctionApp.EventProcessor
{
    public class EventProcessorFunction
    {
        #region Configuration

        private const string StorageContainerName = "tickets";
        private const string BlobNameFormatString = $"ticket-{{{nameof(Event.EntityId)}}}.png";

        private readonly IConfiguration configuration;

        public EventProcessorFunction(IConfiguration configuration)
        {
            this.configuration = configuration;
        }

        #endregion

        #region Run

        [FunctionName("EventProcessor")]
        public async Task Run(
            [QueueTrigger("relecloudconcertevents", Connection = "App:StorageAccount:ConnectionString")]
            Event eventInfo,
            ILogger log)
        {
            log.LogInformation($"Received event type \"{eventInfo.EventType}\" for entity \"{eventInfo.EntityId}\"");

            try
            {
                var entityId = ValidateRequiredConfiguration(eventInfo);

                if (eventInfo.EventType == EventType.TicketCreated)
                {
                    await CreateTicketImageAsync(entityId, log);
                }
            }
            catch (Exception ex)
            {
                log.LogError(ex, "Unable to process the TicketCreated event");
                throw;
            }
        }

        private int ValidateRequiredConfiguration(Event eventInfo)
        {
            var requiredConfiguration = new[]
            {
                "App:SqlDatabase:ConnectionString",
            };
            foreach(var configKey in requiredConfiguration)
            {
                if (string.IsNullOrEmpty(this.configuration[configKey]))
                {
                    throw new ArgumentNullException(configKey);
                }
            }

            if (int.TryParse(eventInfo.EntityId, out int entityId))
            {
                return entityId;
            }
            else
            {
                throw new ArgumentException($"The EntityId {eventInfo.EntityId} must be an integer representing the from a table");
            }
        }

        #endregion

        #region Create Ticket Image

        private async Task CreateTicketImageAsync(int ticketId, ILogger log)
        {
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                throw new PlatformNotSupportedException("Ticket rendering must run on Windows environment");
            }

            var ticketImageBlob = new MemoryStream();
            using (var connection = new SqlConnection(this.configuration["App:SqlDatabase:ConnectionString"]))
            {
                // Retrieve the ticket from the database.
                log.LogInformation($"Retrieving details for ticket \"{ticketId}\" from SQL Database...");
                await connection.OpenAsync();
                var getTicketCommand = connection.CreateCommand();
                getTicketCommand.CommandText = "SELECT Concerts.Artist, Concerts.Location, Concerts.StartTime, Concerts.Price, Users.DisplayName FROM Tickets INNER JOIN Concerts ON Tickets.ConcertId = Concerts.Id INNER JOIN Users ON Tickets.UserId = Users.Id WHERE Tickets.Id = @id";
                getTicketCommand.Parameters.Add(new SqlParameter("id", ticketId));
                using (var ticketDataReader = await getTicketCommand.ExecuteReaderAsync())
                {
                    // Get ticket details.
                    var hasRows = await ticketDataReader.ReadAsync();
                    if (hasRows == false)
                    {
                        log.LogWarning($"No Ticket found for id:{ticketId}");
                        return; //this ticket was not found
                    }

                    var artist = ticketDataReader.GetString(0);
                    var location = ticketDataReader.GetString(1);
                    var startTime = ticketDataReader.GetDateTimeOffset(2);
                    var price = ticketDataReader.GetDouble(3);
                    var userName = ticketDataReader.GetString(4);

                    // Generate the ticket image.
                    using (var headerFont = new Font("Arial", 18, FontStyle.Bold))
                    using (var textFont = new Font("Arial", 12, FontStyle.Regular))
                    using (var bitmap = new Bitmap(640, 200, PixelFormat.Format24bppRgb))
                    using (var graphics = Graphics.FromImage(bitmap))
                    {
                        graphics.SmoothingMode = SmoothingMode.AntiAlias;
                        graphics.Clear(Color.White);

                        // Print concert details.
                        graphics.DrawString(artist, headerFont, Brushes.DarkSlateBlue, new PointF(10, 10));
                        graphics.DrawString($"{location}   |   {startTime.UtcDateTime.ToString()}", textFont, Brushes.Gray, new PointF(10, 40));
                        graphics.DrawString($"{userName}   |   {price.ToString("c")}", textFont, Brushes.Gray, new PointF(10, 60));

                        // Print a fake barcode.
                        var random = new Random();
                        var offset = 15;
                        while (offset < 620)
                        {
                            var width = 2 * random.Next(1, 3);
                            graphics.FillRectangle(Brushes.Black, offset, 90, width, 90);
                            offset += width + (2 * random.Next(1, 3));
                        }

                        // Save to blob storage.
                        log.LogInformation("Uploading image to blob storage...");
                        bitmap.Save(ticketImageBlob, ImageFormat.Png);
                    }
                }
                ticketImageBlob.Position = 0;
                log.LogInformation("Successfully wrote to database.");

                var storageAccountConnStr = this.configuration["App:StorageAccount:ConnectionString"];
                var blobServiceClient = new BlobServiceClient(storageAccountConnStr);

                //  Gets a reference to the container.
                var blobContainerClient = blobServiceClient.GetBlobContainerClient(StorageContainerName);

                //  Gets a reference to the blob in the container
                var blobClient = blobContainerClient.GetBlobClient(BlobNameFormatString.Replace($"{{{nameof(Event.EntityId)}}}", ticketId.ToString()));
                var blobInfo = await blobClient.UploadAsync(ticketImageBlob, overwrite: true);

                log.LogInformation("Successfully wrote blob to storage.");

                // Update the ticket in the database with the image URL.
                // Creates a client to the BlobService using the connection string.

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

                log.LogInformation($"Updating ticket with image URL {queryUri}...");
                var updateTicketCommand = connection.CreateCommand();
                updateTicketCommand.CommandText = "UPDATE Tickets SET ImageUrl=@imageUrl WHERE Id=@id";
                updateTicketCommand.Parameters.Add(new SqlParameter("id", ticketId));
                updateTicketCommand.Parameters.Add(new SqlParameter("imageUrl", queryUri.ToString()));
                await updateTicketCommand.ExecuteNonQueryAsync();

                log.LogInformation("Successfully updated database with SAS.");
            }
        }

        #endregion
    }
}
