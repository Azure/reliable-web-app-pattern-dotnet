namespace Relecloud.Web.Models.TicketManagement
{
    public class PurchaseTicketsResult
    {
        public PurchaseTicketsResultStatus Status { get; set; }

        public IDictionary<string, IEnumerable<string>>? ErrorMessages { get; set; }

        public static PurchaseTicketsResult ErrorResponse(string errorMessage)
        {
            return ErrorResponse(new List<string> { errorMessage });
        }

        public static PurchaseTicketsResult ErrorResponse(IEnumerable<string> errorMessages)
        {
            var errors = new Dictionary<string, IEnumerable<string>>();
            errors[string.Empty] = errorMessages;

            return new PurchaseTicketsResult
            {
                Status = PurchaseTicketsResultStatus.UnableToProcess,
                ErrorMessages = errors,
            };
        }
    }
}
