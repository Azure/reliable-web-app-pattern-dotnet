using System.Collections.Generic;

namespace Relecloud.Mocks.PaymentGateway.Models
{
    public class Order
    {
        public string OrderNumber { get; set; }
        public List<OrderItem> Items { get; set; }
    }
}
