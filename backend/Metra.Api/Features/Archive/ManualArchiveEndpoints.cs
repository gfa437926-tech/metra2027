using System.Collections.Concurrent;
using System.Net;
using System.Security.Claims;
using Metra.Api.Domain.Archive;
using Metra.Api.Security;

namespace Metra.Api.Features.Archive;

public sealed record ManualArchiveConfirmRequest(
    string? ReportKind,
    string? PeriodStartUtc,
    string? PeriodEndUtc,
    string? ExcelFileName,
    string? Note);

public sealed record ManualArchiveServiceOutcome(
    bool Succeeded,
    HttpStatusCode StatusCode,
    object? Data,
    string? Error = null);

public interface IManualArchiveLedgerService
{
    /// <summary>
    /// Interim in-memory ledger is configured for development/tests.
    /// Durable PostgreSQL persistence requires an approved migration apply.
    /// </summary>
    bool IsConfigured { get; }

    Task<ManualArchiveServiceOutcome> ListAsync(Guid stationId, int limit, CancellationToken ct);
    Task<ManualArchiveServiceOutcome> ConfirmAsync(
        Guid stationId, Guid actorUserId, ManualArchiveConfirmRequest request, CancellationToken ct);
    Task<ManualArchiveServiceOutcome> MonthlySummaryAsync(
        Guid stationId, int year, int month, CancellationToken ct);
}

/// <summary>
/// Process-local ledger only. Not a substitute for approved durable storage.
/// Explicitly does not connect to any archive database or migrate observation rows.
/// </summary>
public sealed class InMemoryManualArchiveLedgerService : IManualArchiveLedgerService
{
    private readonly ConcurrentDictionary<string, ManualArchiveConfirmation> _byKey = new(StringComparer.Ordinal);
    private readonly ConcurrentDictionary<Guid, ConcurrentBag<ManualArchiveConfirmation>> _byStation = new();

    public bool IsConfigured => true;

    public Task<ManualArchiveServiceOutcome> ListAsync(Guid stationId, int limit, CancellationToken ct)
    {
        if (stationId == Guid.Empty || limit is < 1 or > 200)
            return Task.FromResult(new ManualArchiveServiceOutcome(false, HttpStatusCode.BadRequest, null, "invalid_request"));

        var bag = _byStation.GetOrAdd(stationId, _ => new ConcurrentBag<ManualArchiveConfirmation>());
        var rows = bag.OrderByDescending(x => x.ConfirmedAtUtc).Take(limit).ToArray();
        return Task.FromResult(new ManualArchiveServiceOutcome(true, HttpStatusCode.OK, rows));
    }

    public Task<ManualArchiveServiceOutcome> ConfirmAsync(
        Guid stationId, Guid actorUserId, ManualArchiveConfirmRequest request, CancellationToken ct)
    {
        if (!DateOnly.TryParse(request.PeriodStartUtc, out var start) ||
            !DateOnly.TryParse(request.PeriodEndUtc, out var end))
        {
            return Task.FromResult(new ManualArchiveServiceOutcome(
                false, HttpStatusCode.BadRequest, null, "invalid_period"));
        }

        var validation = ManualArchiveLedgerPolicy.ValidateRequest(
            stationId, actorUserId, request.ReportKind, start, end, request.ExcelFileName, request.Note);
        if (validation is not null)
            return Task.FromResult(new ManualArchiveServiceOutcome(
                false, HttpStatusCode.BadRequest, null, validation));

        var kind = request.ReportKind!.Trim().ToLowerInvariant();
        var fileName = ManualArchiveLedgerPolicy.NormalizeFileName(request.ExcelFileName!);
        var key = ManualArchiveLedgerPolicy.DuplicateKey(stationId, kind, start, end, fileName);

        var entry = new ManualArchiveConfirmation(
            Guid.NewGuid(),
            stationId,
            actorUserId,
            kind,
            start,
            end,
            fileName,
            string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim(),
            DateTimeOffset.UtcNow);

        if (!_byKey.TryAdd(key, entry))
        {
            return Task.FromResult(new ManualArchiveServiceOutcome(
                false, HttpStatusCode.Conflict, null, "duplicate_archive_confirmation"));
        }

        _byStation.GetOrAdd(stationId, _ => new ConcurrentBag<ManualArchiveConfirmation>()).Add(entry);
        return Task.FromResult(new ManualArchiveServiceOutcome(true, HttpStatusCode.Created, entry));
    }

    public Task<ManualArchiveServiceOutcome> MonthlySummaryAsync(
        Guid stationId, int year, int month, CancellationToken ct)
    {
        if (stationId == Guid.Empty || year is < 2000 or > 2100 || month is < 1 or > 12)
            return Task.FromResult(new ManualArchiveServiceOutcome(
                false, HttpStatusCode.BadRequest, null, "invalid_month"));

        var bag = _byStation.GetOrAdd(stationId, _ => new ConcurrentBag<ManualArchiveConfirmation>());
        var inMonth = bag.Where(x =>
            x.PeriodStartUtc.Year == year && x.PeriodStartUtc.Month == month).ToArray();
        var summary = new ManualArchiveMonthlySummary(
            year,
            month,
            inMonth.Length,
            inMonth.Select(x => x.ReportKind).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x).ToArray());
        return Task.FromResult(new ManualArchiveServiceOutcome(true, HttpStatusCode.OK, summary));
    }
}

public static class ManualArchiveEndpoints
{
    public static IEndpointRouteBuilder MapManualArchiveEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/stations/{stationId:guid}/archive-confirmations",
            async (
                Guid stationId,
                int? limit,
                HttpContext http,
                IManualArchiveLedgerService ledger,
                IStationAuthorizationService authorization,
                CancellationToken ct) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId) || userId == Guid.Empty)
                    return Results.Unauthorized();
                if (!authorization.IsConfigured)
                    return Results.Problem(title: "Authorization service unavailable", statusCode: 503);
                if (!ledger.IsConfigured)
                    return Results.Problem(title: "Archive ledger unavailable", statusCode: 503);

                var take = limit ?? 50;
                if (take is < 1 or > 200)
                    return Results.BadRequest(new { error = "invalid_limit" });

                var allowed = await authorization.HasStationPermissionAsync(
                    userId, stationId, "archive.read", ct);
                if (!allowed)
                    return Results.Forbid();

                var result = await ledger.ListAsync(stationId, take, ct);
                return result.Succeeded
                    ? Results.Ok(result.Data)
                    : Results.BadRequest(new { error = result.Error });
            })
            .RequireStationPermission("archive.read")
            .WithTags("Archive")
            .WithName("ListManualArchiveConfirmations");

        endpoints.MapPost("/api/v1/stations/{stationId:guid}/archive-confirmations",
            async (
                Guid stationId,
                ManualArchiveConfirmRequest? request,
                HttpContext http,
                IManualArchiveLedgerService ledger,
                IStationAuthorizationService authorization,
                CancellationToken ct) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId) || userId == Guid.Empty)
                    return Results.Unauthorized();
                if (request is null)
                    return Results.BadRequest(new { error = "invalid_request" });
                if (!authorization.IsConfigured)
                    return Results.Problem(title: "Authorization service unavailable", statusCode: 503);
                if (!ledger.IsConfigured)
                    return Results.Problem(title: "Archive ledger unavailable", statusCode: 503);

                var allowed = await authorization.HasStationPermissionAsync(
                    userId, stationId, "archive.confirm", ct);
                if (!allowed)
                    return Results.Forbid();

                var result = await ledger.ConfirmAsync(stationId, userId, request, ct);
                if (result.Succeeded)
                    return Results.Json(result.Data, statusCode: StatusCodes.Status201Created);
                if (result.StatusCode == HttpStatusCode.Conflict)
                    return Results.Conflict(new { error = result.Error });
                return Results.BadRequest(new { error = result.Error });
            })
            .RequireStationPermission("archive.confirm")
            .WithTags("Archive")
            .WithName("ConfirmManualArchive");

        endpoints.MapGet("/api/v1/stations/{stationId:guid}/archive-confirmations/monthly-summary",
            async (
                Guid stationId,
                int year,
                int month,
                HttpContext http,
                IManualArchiveLedgerService ledger,
                IStationAuthorizationService authorization,
                CancellationToken ct) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId) || userId == Guid.Empty)
                    return Results.Unauthorized();
                if (!authorization.IsConfigured)
                    return Results.Problem(title: "Authorization service unavailable", statusCode: 503);
                if (!ledger.IsConfigured)
                    return Results.Problem(title: "Archive ledger unavailable", statusCode: 503);

                var allowed = await authorization.HasStationPermissionAsync(
                    userId, stationId, "archive.read", ct);
                if (!allowed)
                    return Results.Forbid();

                var result = await ledger.MonthlySummaryAsync(stationId, year, month, ct);
                return result.Succeeded
                    ? Results.Ok(result.Data)
                    : Results.BadRequest(new { error = result.Error });
            })
            .RequireStationPermission("archive.read")
            .WithTags("Archive")
            .WithName("ManualArchiveMonthlySummary");

        return endpoints;
    }
}
