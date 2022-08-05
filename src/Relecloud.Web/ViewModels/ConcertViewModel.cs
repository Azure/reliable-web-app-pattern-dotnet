using Microsoft.AspNetCore.Mvc.Rendering;
using Relecloud.Web.Models.ConcertContext;

namespace Relecloud.Web.ViewModels
{
    public class ConcertViewModel
    {
        public Concert? Concert { get; set; }

        public List<SelectListItem> GetTicketManagementServiceProviders()
        {
            var items = new List<SelectListItem>();

            foreach(var provider in Enum.GetValues(typeof(TicketManagementServiceProviders)))
            {
                items.Add(new SelectListItem(provider.ToString(), provider.ToString()));
            }

            return items;
        }
    }
}
