using System.Security.Claims;

namespace Metra.Api.Security;

public static class StationAuthorizationEndpointExtensions
{
    public static RouteHandlerBuilder RequireStationPermission(
        this RouteHandlerBuilder builder,
        string permissionCode)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(permissionCode);

        return builder.AddEndpointFilter(async (context, next) =>
        {
            var http = context.HttpContext;
            if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId))
                return Results.Unauthorized();

            if (!Guid.TryParse(Convert.ToString(http.Request.RouteValues["stationId"]), out var stationId))
                return Results.BadRequest(new { error = "invalid_station_id" });

            var authorization = http.RequestServices.GetRequiredService<IStationAuthorizationService>();
            if (!authorization.IsConfigured)
                return Results.Problem(
                    title: "Authorization service unavailable",
                    detail: "The trusted METRA database connection is not configured.",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            var allowed = await authorization.HasStationPermissionAsync(
                userId, stationId, permissionCode, http.RequestAborted);

            return allowed ? await next(context) : Results.Forbid();
        });
    }
}
