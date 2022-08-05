namespace Relecloud.FunctionApp.EventProcessor
{
    public class Event
    {
        public EventType EventType { get; set; }
        public string EntityId { get; set; }
    }
}
