namespace Relecloud.Web.Models.Search
{
    public class ConcertSearchResult
    {
        public string Id { get; set; } = string.Empty;
        public bool IsVisible { get; set; }
        public string Artist { get; set; } = string.Empty;
        public string Genre { get; set; } = string.Empty;
        public string Location { get; set; } = string.Empty;
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public double Price { get; set; }
        public DateTimeOffset StartTime { get; set; }
        public DateTimeOffset CreatedOn { get; set; }
        public string CreatedBy { get; set; } = string.Empty;
        public DateTimeOffset UpdatedOn { get; set; }
        public string UpdatedBy { get; set; } = string.Empty;

        public double Score { get; set; }
        public IList<string> HitHighlights { get; set; } = new List<string>();
    }
}