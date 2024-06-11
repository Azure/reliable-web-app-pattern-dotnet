using Microsoft.AspNetCore.Html;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.AspNetCore.Mvc.Rendering;
using Relecloud.Web.Models.ConcertContext;
using Relecloud.Web.Models.Search;
using System.Security.Claims;
using System.Text.Json;

namespace Relecloud.Web.Infrastructure
{
    public static class ExtensionMethods
    {
        public static string GetUniqueId(this ClaimsPrincipal user)
        {
            // Azure AD issues a globally unique user ID in the objectidentifier claim.
            return user?.FindFirstValue("http://schemas.microsoft.com/identity/claims/objectidentifier") ?? new Guid().ToString();
        }

        public static void Set<T>(this ISession session, string key, T value)
        {
            session.SetString(key, JsonSerializer.Serialize(value));
        }

        public static T? Get<T>(this ISession session, string key)
        {
            var value = session.GetString(key);
            return value == null ? default(T) : JsonSerializer.Deserialize<T>(value);
        }

        public static IHtmlContent LinkForPage(this IHtmlHelper html, SearchRequest request, int pageNumber)
        {
            var routeValues = request.Clone();
            routeValues.CurrentPage = pageNumber;
            return html.ActionLink((pageNumber + 1).ToString(), "Search", "Concert", null, null, null, routeValues, null);
        }

        public static IHtmlContent LinkForSortType(this IHtmlHelper html, SearchRequest request, string sortOn, bool sortDescending, string linkText)
        {
            var routeValues = request.Clone();
            if (string.Equals(routeValues.SortOn, sortOn) && routeValues.SortDescending == sortDescending)
            {
                routeValues.SortDescending = false;
                linkText = "[X] " + linkText;
            }
            else
            {
                routeValues.SortOn = sortOn;
                routeValues.SortDescending = sortDescending;
            }
            return html.ActionLink(linkText, "Search", "Concert", null, null, null, routeValues, null);
        }

        public static IHtmlContent LinkForSearchFacet(this IHtmlHelper html, SearchRequest request, SearchFacet facet, SearchFacetValue facetValue)
        {
            var routeValues = request.Clone();
            var linkText = $"{facetValue.DisplayName} ({facetValue.Count})";
            if (string.Equals(facet.FieldName, nameof(Concert.Price), StringComparison.OrdinalIgnoreCase))
            {
                if (!string.IsNullOrWhiteSpace(routeValues.PriceRange))
                {
                    linkText = "[X] " + linkText;
                }
                else
                {
                    routeValues.PriceRange = facetValue.Value;
                }
            }
            else if (string.Equals(facet.FieldName, nameof(Concert.Genre), StringComparison.OrdinalIgnoreCase))
            {
                if (!string.IsNullOrWhiteSpace(routeValues.Genre))
                {
                    linkText = "[X] " + linkText;
                }
                else
                {
                    routeValues.Genre = facetValue.Value;
                }
            }
            else if (string.Equals(facet.FieldName, nameof(Concert.Location), StringComparison.OrdinalIgnoreCase))
            {
                if (!string.IsNullOrWhiteSpace(routeValues.Location))
                {
                    linkText = "[X] " + linkText;
                }
                else
                {
                    routeValues.Location = facetValue.Value;
                }
            }
            return html.ActionLink(linkText, "Search", "Concert", null, null, null, routeValues, null);
        }

        public static void AddErrorMessages(this ModelStateDictionary modelStateDictionary, IDictionary<string, IEnumerable<string>>? errorMessages)
        {
            if (modelStateDictionary == null || errorMessages == null)
            {
                return;
            }

            foreach (var errorMessage in errorMessages)
            {
                foreach (var errorText in errorMessage.Value)
                {
                    modelStateDictionary.AddModelError(errorMessage.Key, errorText);
                }
            }
        }
    }
}
