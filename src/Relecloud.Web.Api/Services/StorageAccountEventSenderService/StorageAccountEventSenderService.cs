using Azure.Identity;
using Azure.Storage.Queues;
using Relecloud.Web.Models.Events;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Relecloud.Web.Api.Services.StorageAccountEventSenderService
{
    public class StorageAccountEventSenderService : IAzureEventSenderService
    {
        private readonly QueueClient queue;

        public StorageAccountEventSenderService(string serviceUri, string queueName)
        {
            var queueUri = new Uri(serviceUri+queueName);

            this.queue = new QueueClient(queueUri, new DefaultAzureCredential(), new QueueClientOptions
            {
                MessageEncoding = QueueMessageEncoding.Base64
            });
        }

        public void Initialize()
        {
            this.queue.CreateIfNotExistsAsync().Wait();
        }

        public async Task SendEventAsync(Event eventData)
        {
            var options = new JsonSerializerOptions
            {
                WriteIndented = true,
                Converters =
                {
                    new JsonStringEnumConverter(JsonNamingPolicy.CamelCase)
                }
            };
            var body = JsonSerializer.Serialize(eventData, options);
            await this.queue.SendMessageAsync(body);
        }
    }
}