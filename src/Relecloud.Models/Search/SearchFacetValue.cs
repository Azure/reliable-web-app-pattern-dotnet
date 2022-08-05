namespace Relecloud.Web.Models.Search
{
    public class SearchFacetValue
    {
        public string Value { get; set; }
        public string DisplayName { get; set; }
        public long Count { get; set; }

        public SearchFacetValue(string value, string displayName, long count)
        {
            this.Value = value;
            this.DisplayName = displayName;
            this.Count = count;
        }
    }
}
