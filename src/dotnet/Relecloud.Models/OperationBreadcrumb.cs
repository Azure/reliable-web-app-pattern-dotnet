using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Relecloud.Web.Models
{
    public class OperationBreadcrumb
    {
        public string OperationStatus { get; set; }
        public string OperationName { get; set; }
        public string SessionId { get; set; }
        public string RequestId { get; set; }

        public static OperationBreadcrumb Create(string sessionId, string requestId, string operationStatus, string operationName)
        {
            return new OperationBreadcrumb()
            {
                SessionId = sessionId,
                RequestId = requestId,
                OperationStatus = operationStatus,
                OperationName = operationName
            };
        }
    }
}
