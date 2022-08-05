using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace Relecloud.Web.Api.Infrastructure
{
    public static class ModelStateDictionaryExtensions
    {
        public static IDictionary<string, IEnumerable<string>> ServerError(this ModelStateDictionary modelStateDictionary, string customErrorMessage)
        {
            var errors = new Dictionary<string, IEnumerable<string>>();
            errors.Add(string.Empty, new List<string> { customErrorMessage });
            return errors;
        }

        public static IDictionary<string, IEnumerable<string>> ConvertToErrorMessages(this ModelStateDictionary modelStateDictionary)
        {
            var errorMessages = new Dictionary<string, IEnumerable<string>>();
            if (modelStateDictionary == null)
            {
                return errorMessages;
            }

            foreach(var error in modelStateDictionary)
            {
                var errorMessageList = error.Value.Errors.Where(err => !string.IsNullOrEmpty(err.ToString())).Select(err => err.ToString());
                if (errorMessageList != null)
                {
                    errorMessages.Add(error.Key, errorMessageList!);
                }
            }

            return errorMessages;
        }
    }
}
