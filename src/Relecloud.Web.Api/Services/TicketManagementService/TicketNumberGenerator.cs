using System.Text;

namespace Relecloud.Web.Api.Services.TicketManagementService
{
    public class TicketNumberGenerator : ITicketNumberGenerator
    {
        private static Random random = new Random();

        public string Generate(int ticketNumberLength = 50)
        {
            var holdCodeBuffer = new StringBuilder();
            for (int i = 0; i < ticketNumberLength; i++)
            {
                if (random.Next(0, 2) > 0)
                {
                    holdCodeBuffer.Append(Convert.ToChar(65 + random.Next(0, 26)));
                }
                else
                {
                    holdCodeBuffer.Append(random.Next(0, 10));
                }
            }

            return holdCodeBuffer.ToString();
        }
    }
}
