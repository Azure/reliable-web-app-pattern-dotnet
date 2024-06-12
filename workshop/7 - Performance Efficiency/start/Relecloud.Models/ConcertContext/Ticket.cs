namespace Relecloud.Web.Models.ConcertContext
{
    public class Ticket
    {
        public int Id { get; set; }
        public string ImageName { get; set; } = string.Empty;

        public int ConcertId { get; set; }
        public Concert? Concert { get; set; }

        public string UserId { get; set; } = string.Empty;
        public User? User { get; set; }

        public int CustomerId { get; set; }
        public Customer? Customer { get; set; }

        public string TicketNumber { get; set; } = string.Empty;
    }
}