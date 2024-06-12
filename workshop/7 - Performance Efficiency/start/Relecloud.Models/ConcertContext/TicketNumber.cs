namespace Relecloud.Web.Models.ConcertContext
{
    public class TicketNumber
    {
        public int Id { get; set; }
        public string Number { get; set; } = string.Empty;

        public int? TicketId { get; set; }

        public Ticket? Ticket { get; set; }

        public int ConcertId { get; set; }
    }
}
