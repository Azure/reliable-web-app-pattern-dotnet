namespace Relecloud.Web.Models.ConcertContext
{
    public class Concert
    {
        public int Id { get; set; }
        public bool IsVisible { get; set; }
        public string Artist { get; set; } = string.Empty;
        public string Genre { get; set; } = string.Empty;
        public string Location { get; set; } = string.Empty;
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public double Price { get; set; }
        public DateTimeOffset StartTime { get; set; } = DateTimeOffset.UtcNow.AddDays(30);
        public DateTimeOffset CreatedOn { get; set; }
        public string CreatedBy { get; set; } = string.Empty;
        public DateTimeOffset UpdatedOn { get; set; }
        public string UpdatedBy { get; set; } = string.Empty;

        public TicketManagementServiceProviders TicketManagementServiceProvider { get; set; }

        /// <summary>
        /// Required when the selected Ticket Management Service is not ReleCloud Api
        /// </summary>
        public string? TicketManagementServiceConcertId { get; set; } = string.Empty;


        /// <summary>
        /// This is a calculated column that does not exist in the DB
        /// </summary>
        public int? NumberOfTicketsForSale { get; set; }
    }
}