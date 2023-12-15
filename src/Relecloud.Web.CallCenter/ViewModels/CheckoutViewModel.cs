using Microsoft.AspNetCore.Mvc.Rendering;
using Relecloud.Web.Models.TicketManagement.Payment;
using System.ComponentModel.DataAnnotations;

namespace Relecloud.Web.CallCenter.ViewModels
{
    public class CheckoutViewModel
    {
        public CartViewModel? Cart { get; set; }

        [Required]
        public PaymentDetails? PaymentDetails { get; set; }

        public List<SelectListItem> GetCardTypeList()
        {
            return Enum.GetValues<CardTypes>().Select(c => new SelectListItem(c.ToString(), c.ToString())).ToList();
        }

        public List<SelectListItem> GetSampleSecurityCodes()
        {
            return new List<SelectListItem>
            {
                new SelectListItem("Valid Security Code","123"),
                new SelectListItem("Invalid Security Code","124"),
            };
        }

        public List<SelectListItem> GetSampleCardNumbers()
        {
            return new List<SelectListItem>
            {
                new SelectListItem("Visa - Succeeds", "4242424242424242"),
                new SelectListItem("Visa - Insufficient Funds", "4000000000009995"),
            };
        }
    }
}
