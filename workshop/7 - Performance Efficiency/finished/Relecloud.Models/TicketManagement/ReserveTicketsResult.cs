namespace Relecloud.Web.Models.TicketManagement
{
    public class ReserveTicketsResult
    {
        public ICollection<string> TicketNumbers { get; set; } = new List<string>();

        public ReserveTicketsResultStatus Status { get; set; }

        public string ErrorMessage { get; set; } = string.Empty;
    }
}
