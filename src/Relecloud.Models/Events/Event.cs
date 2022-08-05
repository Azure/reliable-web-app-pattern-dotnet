namespace Relecloud.Web.Models.Events
{
    public class Event
    {
        #region Properties

        public EventType EventType { get; set; }
        public string EntityId { get; set; } = Guid.NewGuid().ToString();

        #endregion

        #region Static Factory Methods

        public static Event ReviewCreated(int reviewId)
        {
            return new Event
            {
                EventType = EventType.ReviewCreated,
                EntityId = reviewId.ToString()
            };
        }

        public static Event TicketCreated(int ticketId)
        {
            return new Event
            {
                EventType = EventType.TicketCreated,
                EntityId = ticketId.ToString()
            };
        }

        #endregion
    }
}