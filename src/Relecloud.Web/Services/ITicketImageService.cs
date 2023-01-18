using Relecloud.Web.Infrastructure;

using Relecloud.Web.Models.TicketManagement;

using System.Net;
using Azure.Core;

namespace Relecloud.Web.Services;

public interface ITicketImageService
{
    Task<Stream> GetTicketImagesAsync(string imageName);
}
