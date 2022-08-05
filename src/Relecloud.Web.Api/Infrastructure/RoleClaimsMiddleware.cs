using System.Security.Claims;

namespace Relecloud.Web.Api.Infrastructure
{
    public class RoleClaimsMiddleware
    {
        private readonly RequestDelegate _next;
        private const string RoleClaim = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role";

        public RoleClaimsMiddleware(RequestDelegate next)
        {
            _next = next;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var identity = context.User.Identity as ClaimsIdentity;
            if (identity != null)
            {
                var claimType = "extension_AppRoles";

                // Find all claims of the requested claim type, split their values by spaces
                // and then take the ones that aren't yet on the principal individually.
                var claims = identity.FindAll(claimType)
                    .SelectMany(c => c.Value.Split(' ', StringSplitOptions.RemoveEmptyEntries))
                    .Where(s => !identity.HasClaim(claimType, s)).ToList();

                identity.AddClaims(claims.Select(s => new Claim(RoleClaim, s)));
            }

            await _next(context);
        }
    }

    public static class RoleClaimsMiddlewareExtensions
    {
        public static IApplicationBuilder UseRoleClaimsMiddleware(
            this IApplicationBuilder builder)
        {
            return builder.UseMiddleware<RoleClaimsMiddleware>();
        }
    }
}