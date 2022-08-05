using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Relecloud.Web.Models.TicketManagement
{
    public enum ReserveTicketsResultStatus
    {
        NotEnoughTicketsRemaining,
        Success,
        ConcertNotFound
    }
}
