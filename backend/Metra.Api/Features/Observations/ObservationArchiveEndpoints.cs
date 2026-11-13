using System.Security.Claims;
using Metra.Api.Domain.Observations;
using Metra.Api.Security;
using Microsoft.AspNetCore.Mvc;

namespace Metra.Api.Features.Observations;

/// <summary>
/// Station-scoped observation archive read contract.
/// Production data access remains fail-closed until an approved, isolated
/// archive read model and explicit observation.archive.read grants exist.
/// This endpoint enforces the approved authorization policy and returns
/// structured contract errors without inventing historical data.
/// </summary>
public interface IObservationArchiveService
{
    bool IsConfigured { get; }

    Task<ObservationArchiveListResult?> ListAsync(
        Guid stationId,
        DateTime? fromUtc,
        DateTime? toUtc,
        string? observationType,
        int limit,
        string? cursor,
        CancellationToken cancellationToken);

    Task<ObservationArchiveItemDto?> GetAsync(
        Guid stationId,
        Guid observationId,
        CancellationToken cancellationToken);
}

public sealed record ObservationArchiveListResult(
    IReadOnlyList<ObservationArchiveItemDto> Items,
    bool HasMore,
    string? NextCursor);

public sealed record ObservationArchiveItemDto(
    string Id,
    string StationId,
    string ObservationType,
    DateTime? ObservedAtUtc,
    DateTime ImportedAtUtc,
    string SourceSystem,
    string SourceTable,
    string SourceRecordId,
    IReadOnlyDictionary<string, object?> Payload);

/// <summary>
/// Placeholder archive service: always reports not configured so the API
/// fails closed. Replace only after isolated DB read-model + grants ship.
/// </summary>
public sealed class UnconfiguredObservationArchiveService : IObservationArchiveService
{
    public bool IsConfigured => false;

    public Task<ObservationArchiveListResult?> ListAsync(
        Guid stationId,
        DateTime? fromUtc,
        DateTime? toUtc,
        string? observationType,
        int limit,
        string? cursor,
        CancellationToken cancellationToken)
        => Task.FromResult<ObservationArchiveListResult?>(null);

    public Task<ObservationArchiveItemDto?> GetAsync(
        Guid stationId,
        Guid observationId,
        CancellationToken cancellationToken)
        => Task.FromResult<ObservationArchiveItemDto?>(null);
}

public static class ObservationArchiveEndpoints
{
    public static IEndpointRouteBuilder MapObservationArchiveEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet(
            "/api/v1/stations/{stationId:guid}/observation-archive",
            async (
                Guid stationId,
                [FromQuery] DateTime? fromUtc,
                [FromQuery] DateTime? toUtc,
                [FromQuery] string? observationType,
                [FromQuery] int? limit,
                [FromQuery] string? cursor,
                HttpContext http,
                IStationAuthorizationService authorization,
                IObservationArchiveService archive,
                CancellationToken cancellationToken) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId))
                    return Results.Unauthorized();

                if (stationId == Guid.Empty)
                    return Results.BadRequest(new { code = "station_required" });

                var pageSize = limit is null ? 25 : Math.Clamp(limit.Value, 1, 100);

                // Server-side station authorization (assignment + explicit archive grant).
                // Never trust client role claims. Fail closed on any uncertainty.
                var allowed = await authorization.HasStationArchivePermissionAsync(
                    userId,
                    stationId,
                    cancellationToken);

                if (!allowed)
                {
                    return Results.Json(
                        new
                        {
                            code = "archive_permission_denied",
                            message =
                                "قراءة الأرشيف تتطلب منحة صريحة observation.archive.read لهذه المحطة تحديداً. لا تُستنتج من الدور أو عضوية الجهة."
                        },
                        statusCode: StatusCodes.Status403Forbidden);
                }

                // Domain policy double-check (station scope isolation).
                var actor = new ObservationActorContext(
                    userId.ToString("D"),
                    stationId.ToString("D"),
                    HasActiveStationAssignment: true,
                    Permissions: new HashSet<ObservationPermission> { ObservationPermission.ArchiveRead });

                var policy = ObservationArchiveAuthorizationPolicy.AuthorizeArchiveRead(
                    actor, stationId.ToString("D"));
                if (!policy.IsAuthorized)
                {
                    return Results.Json(
                        new { code = policy.ErrorCode, message = policy.Message },
                        statusCode: StatusCodes.Status403Forbidden);
                }

                if (!archive.IsConfigured)
                {
                    return Results.Json(
                        new
                        {
                            code = "archive_service_unavailable",
                            message =
                                "خدمة أرشيف الرصدات غير مفعّلة بعد. لا تُعرض بيانات تاريخية تجريبية. يتطلب نموذجاً معزولاً ومنحاً صريحة لكل محطة."
                        },
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }

                var result = await archive.ListAsync(
                    stationId, fromUtc, toUtc, observationType, pageSize, cursor, cancellationToken);

                if (result is null)
                {
                    return Results.Json(
                        new { code = "archive_unavailable", message = "تعذر قراءة الأرشيف." },
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }

                return Results.Ok(new
                {
                    items = result.Items,
                    hasMore = result.HasMore,
                    nextCursor = result.NextCursor
                });
            })
            .RequireAuthorization()
            .RequireRateLimiting(MetraRateLimiting.PolicyRead)
            .WithName("ListStationObservationArchive")
            .WithTags("Observations", "Archive")
            .WithSummary("List station-scoped observation archive (explicit archive grant required)")
            .WithDescription(
                "Requires authenticated user, active station assignment, and explicit " +
                "observation.archive.read grant for this station only. Authority membership " +
                "or role alone is insufficient. Cross-station access is denied.");

        endpoints.MapGet(
            "/api/v1/stations/{stationId:guid}/observation-archive/{observationId:guid}",
            async (
                Guid stationId,
                Guid observationId,
                HttpContext http,
                IStationAuthorizationService authorization,
                IObservationArchiveService archive,
                CancellationToken cancellationToken) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId))
                    return Results.Unauthorized();

                if (stationId == Guid.Empty || observationId == Guid.Empty)
                    return Results.BadRequest(new { code = "archive_identifier_required" });

                var allowed = await authorization.HasStationArchivePermissionAsync(
                    userId,
                    stationId,
                    cancellationToken);
                if (!allowed)
                    return Results.Json(
                        new { code = "archive_permission_denied" },
                        statusCode: StatusCodes.Status403Forbidden);

                var actor = new ObservationActorContext(
                    userId.ToString("D"),
                    stationId.ToString("D"),
                    HasActiveStationAssignment: true,
                    Permissions: new HashSet<ObservationPermission> { ObservationPermission.ArchiveRead });
                var policy = ObservationArchiveAuthorizationPolicy.AuthorizeArchiveRead(
                    actor, stationId.ToString("D"));
                if (!policy.IsAuthorized)
                    return Results.Json(
                        new { code = policy.ErrorCode, message = policy.Message },
                        statusCode: StatusCodes.Status403Forbidden);

                if (!archive.IsConfigured)
                    return Results.Json(
                        new
                        {
                            code = "archive_service_unavailable",
                            message = "خدمة أرشيف الرصدات غير مفعّلة بعد."
                        },
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                var item = await archive.GetAsync(stationId, observationId, cancellationToken);
                return item is null
                    ? Results.NotFound(new { code = "archive_record_not_found" })
                    : Results.Ok(item);
            })
            .RequireAuthorization()
            .RequireRateLimiting(MetraRateLimiting.PolicyRead)
            .WithName("GetStationObservationArchiveItem")
            .WithTags("Observations", "Archive")
            .WithSummary("Get one station-scoped observation archive item");

        return endpoints;
    }
}
