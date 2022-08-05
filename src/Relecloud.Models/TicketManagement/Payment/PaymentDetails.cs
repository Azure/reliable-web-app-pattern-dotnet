using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

namespace Relecloud.Web.Models.TicketManagement.Payment
{
    public class PaymentDetails : IValidatableObject
    {
        [Required]
        [MaxLength(70)]
        [DisplayName("Name on card")]
        public string NameOnCard { get; set; } = string.Empty;

        [Required]
        [MaxLength(16)]
        [DisplayName("Card number")]
        // sample code -  a stronger credit card validation process is recommended
        [RegularExpression("^(4)[0-9]{15}$", ErrorMessage = "Please enter a valid credit card number")]

        public string CardNumber { get; set; } = string.Empty;

        [Required]
        [MaxLength(3)]
        [DisplayName("Security code")]
        [RegularExpression("^[0-9]{3}$", ErrorMessage = "Please enter a valid security code")]
        public string SecurityCode { get; set; } = string.Empty;

        [Required]
        [DisplayName("Card type")]
        public CardTypes CardType { get; set; } = CardTypes.VISA;

        [Required]
        [MaxLength(4)]
        [DisplayName("Expiration")]
        [RegularExpression("^[0,1][0-9][2,3][0-9]$", ErrorMessage = "The expiration date must be MMYY format")]
        public string ExpirationMonthYear { get; set; } = DateTimeOffset.UtcNow.AddDays(90).ToString("MMyy");

        public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
        {
            if (!string.IsNullOrEmpty(ExpirationMonthYear) && ExpirationMonthYear.Length == 4)
            {
                var monthSplitString = ExpirationMonthYear.Substring(0, 2);
                var yearSplitString = ExpirationMonthYear.Substring(2,2);
                if (int.TryParse(monthSplitString, out int cardExpirationMonth) && int.TryParse(yearSplitString, out int cardExpirationYear))
                {
                    if ((DateTimeOffset.UtcNow.Year > cardExpirationYear + 2000)
                        || (DateTimeOffset.UtcNow.Year == cardExpirationYear + 2000 && DateTime.UtcNow.Month > cardExpirationMonth))
                    {
                        yield return new ValidationResult("Please use a card that has not expired", new[] { nameof(ExpirationMonthYear) });
                    }
                    if (cardExpirationMonth > 12)
                    {
                        yield return new ValidationResult("The expiration date must be MMYY format", new[] { nameof(ExpirationMonthYear) });
                    }
                }
            }
        }
    }
}
