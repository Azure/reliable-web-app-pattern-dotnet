using System;
using System.Text;

namespace Relecloud.Mocks.PaymentGateway
{
    internal static class RandomCodeGenerator
    {
        private static Random random = new Random();

        internal static string GenerateRandomCode()
        {
            var holdCodeBuffer = new StringBuilder();
            for (int i = 0; i < 50; i++)
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
