using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Security;
using Microsoft.AspNetCore.Mvc;

namespace Metra.Api.Features.Observations;

public interface IObservationArchiveService
{
    bool IsConfigured { get; }
    Task<bool> ProbeAsync(CancellationToken cancellationToken);

    Task<ObservationArchiveListResult?> ListAsync(
        Guid actorUserId,
        Guid stationId,
        DateTime? fromUtc,
        DateTime? toUtc,
        string? observationType,
        int limit,
        string? cursor,
        CancellationToken cancellationToken);

    Task<ObservationArchiveItemDto?> GetAsync(
        Guid actorUserId,
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

public sealed class ObservationArchiveForbiddenException(bool isPolicyDenial = false) : Exception("Station archive permission denied.")
{
    public bool IsPolicyDenial { get; } = isPolicyDenial;
}

/// <summary>
/// Reads the real metra_observation_records archive through actor-bound atomic RPCs.
/// The JWT subject is passed by the endpoint; the service-role credential never leaves the API.
/// </summary>
public sealed class SupabaseObservationArchiveService(
    IHttpClientFactory clients,
    IConfiguration configuration) : IObservationArchiveService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key);

    /// <summary>
    /// Verifies that both protected archive RPC entry points and their shared
    /// authorization helper are installed. Empty actor/station IDs must be
    /// rejected by the database; a 403 is the expected healthy response.
    /// No archive rows or user data are requested by this probe.
    /// </summary>
    public async Task<bool> ProbeAsync(CancellationToken cancellationToken)
    {
        if (!IsConfigured) return false;

        var listDenied = await IsExpectedAuthorizationDenialAsync(
            "get_station_observation_archive_atomic",
            new
            {
                p_actor_user_id = Guid.Empty,
                p_station_id = Guid.Empty,
                p_from_utc = (DateTime?)null,
                p_to_utc = (DateTime?)null,
                p_observation_type = (string?)null,
                p_limit = 1,
                p_cursor = (string?)null
            },
            cancellationToken);
        if (!listDenied) return false;

        return await IsExpectedAuthorizationDenialAsync(
            "get_station_observation_archive_item_atomic",
            new
            {
                p_actor_user_id = Guid.Empty,
                p_station_id = Guid.Empty,
                p_observation_id = Guid.Empty
            },
            cancellationToken);
    }

    private async Task<bool> IsExpectedAuthorizationDenialAsync(
        string functionName,
        object body,
        CancellationToken cancellationToken)
    {
        try
        {
            await CallRpcAsync(functionName, body, cancellationToken);
            // A successful response for an empty actor is a security failure;
            // null means the function/schema/network is unavailable.
            return false;
        }
        catch (ObservationArchiveForbiddenException exception)
        {
            // Only the RPC's explicit actor/station policy denial proves that
            // the function and its authorization helper are installed. A
            // service_role EXECUTE denial must not make readiness look healthy.
            return exception.IsPolicyDenial;
        }
    }

    public async Task<ObservationArchiveListResult?> ListAsync(
        Guid actorUserId,
        Guid stationId,
        DateTime? fromUtc,
        DateTime? toUtc,
        string? observationType,
        int limit,
        string? cursor,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || actorUserId == Guid.Empty || stationId == Guid.Empty ||
            limit is < 1 or > 100 || cursor?.Length > 200)
            return null;

        var result = await CallRpcAsync(
            "get_station_observation_archive_atomic",
            new
            {
                p_actor_user_id = actorUserId,
                p_station_id = stationId,
                p_from_utc = NormalizeUtc(fromUtc),
                p_to_utc = NormalizeUtc(toUtc),
                p_observation_type = observationType,
                p_limit = limit,
                p_cursor = cursor
            },
            cancellationToken);

        if (result is null || result.Value.ValueKind != JsonValueKind.Object)
            return null;

        var root = result.Value;
        if (!root.TryGetProperty("items", out var itemArray) ||
            itemArray.ValueKind != JsonValueKind.Array ||
            !root.TryGetProperty("hasMore", out var hasMoreElement) ||
            hasMoreElement.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
            return null;

        var items = new List<ObservationArchiveItemDto>();
        foreach (var item in itemArray.EnumerateArray())
        {
            var mapped = MapItem(item);
            if (mapped is null) return null;
            items.Add(mapped);
        }

        var nextCursor = root.TryGetProperty("nextCursor", out var cursorElement) &&
            cursorElement.ValueKind == JsonValueKind.String
                ? cursorElement.GetString()
                : null;

        return new ObservationArchiveListResult(items, hasMoreElement.GetBoolean(), nextCursor);
    }

    public async Task<ObservationArchiveItemDto?> GetAsync(
        Guid actorUserId,
        Guid stationId,
        Guid observationId,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || actorUserId == Guid.Empty ||
            stationId == Guid.Empty || observationId == Guid.Empty)
            return null;

        var result = await CallRpcAsync(
            "get_station_observation_archive_item_atomic",
            new
            {
                p_actor_user_id = actorUserId,
                p_station_id = stationId,
                p_observation_id = observationId
            },
            cancellationToken);

        if (result is null || result.Value.ValueKind == JsonValueKind.Null)
            return null;
        return result.Value.ValueKind == JsonValueKind.Object ? MapItem(result.Value) : null;
    }

    private async Task<JsonElement?> CallRpcAsync(
        string functionName,
        object body,
        CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(
            HttpMethod.Post, $"{_url!.TrimEnd('/')}/rest/v1/rpc/{functionName}");
        request.Headers.TryAddWithoutValidation("apikey", _key);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);
        request.Content = JsonContent.Create(body);

        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseObservationArchiveService))
                .SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                var mappedStatus = await SupabaseRpcErrorHandling.MapDatabaseErrorStatusAsync(response, cancellationToken);
                if (mappedStatus == HttpStatusCode.Forbidden)
                {
                    var errorBody = await response.Content.ReadAsStringAsync(cancellationToken);
                    var isPolicyDenial = errorBody.Contains(
                        "station_observation_archive_forbidden", StringComparison.Ordinal);
                    throw new ObservationArchiveForbiddenException(isPolicyDenial);
                }
                return null;
            }
            return await response.Content.ReadFromJsonAsync<JsonElement>(
                cancellationToken: cancellationToken);
        }
        catch (HttpRequestException)
        {
            return null;
        }
        catch (JsonException)
        {
            return null;
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return null;
        }
    }

    private static DateTime? NormalizeUtc(DateTime? value) =>
        value is null ? null : value.Value.Kind == DateTimeKind.Utc
            ? value.Value
            : value.Value.ToUniversalTime();

    private static ObservationArchiveItemDto? MapItem(JsonElement item)
    {
        if (item.ValueKind != JsonValueKind.Object ||
            !TryGetString(item, "id", out var id) ||
            !TryGetString(item, "stationId", out var stationId) ||
            !TryGetString(item, "observationType", out var observationType) ||
            !TryGetDateTime(item, "importedAtUtc", out var importedAt) ||
            !TryGetString(item, "sourceSystem", out var sourceSystem) ||
            !TryGetString(item, "sourceTable", out var sourceTable) ||
            !TryGetString(item, "sourceRecordId", out var sourceRecordId))
            return null;

        DateTime? observedAt = null;
        if (item.TryGetProperty("observedAtUtc", out var observedElement) &&
            observedElement.ValueKind == JsonValueKind.String &&
            observedElement.TryGetDateTime(out var parsedObserved))
            observedAt = parsedObserved;

        var payload = new Dictionary<string, object?>(StringComparer.Ordinal);
        if (item.TryGetProperty("payload", out var payloadElement) &&
            payloadElement.ValueKind == JsonValueKind.Object)
        {
            try
            {
                payload = JsonSerializer.Deserialize<Dictionary<string, object?>>(
                    payloadElement.GetRawText()) ?? payload;
            }
            catch (JsonException)
            {
                return null;
            }
        }
        else
        {
            return null;
        }

        return new ObservationArchiveItemDto(
            id, stationId, observationType, observedAt, importedAt,
            sourceSystem, sourceTable, sourceRecordId, payload);
    }

    private static bool TryGetString(JsonElement element, string name, out string value)
    {
        value = string.Empty;
        return element.TryGetProperty(name, out var property) &&
            property.ValueKind == JsonValueKind.String &&
            !string.IsNullOrWhiteSpace(value = property.GetString() ?? string.Empty);
    }

    private static bool TryGetDateTime(JsonElement element, string name, out DateTime value)
    {
        value = default;
        return element.TryGetProperty(name, out var property) &&
            property.ValueKind == JsonValueKind.String &&
            property.TryGetDateTime(out value);
    }
}

public static class ObservationArchiveEndpoints
{
    private static readonly HashSet<string> AllowedTypes = new(StringComparer.Ordinal)
    {
        "hourly", "daily", "climate", "soil", "agricultural", "phenomenon", "fieldclimate"
    };

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
                IObservationArchiveService archive,
                CancellationToken cancellationToken) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var actorUserId))
                    return Results.Unauthorized();
                if (stationId == Guid.Empty)
                    return Results.BadRequest(new { code = "station_required" });

                if (limit is < 1 or > 100)
                    return Results.BadRequest(new { code = "invalid_archive_limit", maximum = 100 });
                if (cursor?.Length > 200)
                    return Results.BadRequest(new { code = "invalid_archive_cursor" });
                if (fromUtc.HasValue && toUtc.HasValue && fromUtc.Value >= toUtc.Value)
                    return Results.BadRequest(new { code = "invalid_archive_date_range" });

                var type = string.IsNullOrWhiteSpace(observationType) ? null : observationType.Trim();
                if (type is not null && !AllowedTypes.Contains(type))
                    return Results.BadRequest(new { code = "invalid_archive_observation_type" });

                if (!archive.IsConfigured)
                    return Results.Json(
                        new { code = "archive_service_unavailable", message = "خدمة الأرشيف غير مهيأة." },
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                try
                {
                    var result = await archive.ListAsync(
                        actorUserId, stationId, fromUtc, toUtc, type, limit ?? 25, cursor, cancellationToken);
                    if (result is null)
                        return Results.Json(
                            new { code = "archive_unavailable", message = "تعذر قراءة الأرشيف." },
                            statusCode: StatusCodes.Status503ServiceUnavailable);

                    return Results.Ok(new
                    {
                        items = result.Items,
                        hasMore = result.HasMore,
                        nextCursor = result.NextCursor
                    });
                }
                catch (ObservationArchiveForbiddenException)
                {
                    return Results.Json(
                        new
                        {
                            code = "archive_permission_denied",
                            message = "لا يملك المستخدم منحة أرشيف سارية مع تكليف نشط لهذه المحطة."
                        },
                        statusCode: StatusCodes.Status403Forbidden);
                }
            })
            .RequireAuthorization()
            .RequireRateLimiting(MetraRateLimiting.PolicyRead)
            .WithName("ListStationObservationArchive")
            .WithTags("Observations", "Archive")
            .WithSummary("List station-scoped historical observations")
            .WithDescription(
                "The JWT subject and station-bound authorization are verified inside the same database RPC transaction. Unlinked and demo archive records are never returned.");

        endpoints.MapGet(
            "/api/v1/stations/{stationId:guid}/observation-archive/{observationId:guid}",
            async (
                Guid stationId,
                Guid observationId,
                HttpContext http,
                IObservationArchiveService archive,
                CancellationToken cancellationToken) =>
            {
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var actorUserId))
                    return Results.Unauthorized();
                if (stationId == Guid.Empty || observationId == Guid.Empty)
                    return Results.BadRequest(new { code = "archive_identifier_required" });
                if (!archive.IsConfigured)
                    return Results.Json(
                        new { code = "archive_service_unavailable" },
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                try
                {
                    var item = await archive.GetAsync(
                        actorUserId, stationId, observationId, cancellationToken);
                    return item is null
                        ? Results.NotFound(new { code = "archive_record_not_found" })
                        : Results.Ok(item);
                }
                catch (ObservationArchiveForbiddenException)
                {
                    return Results.Json(
                        new { code = "archive_permission_denied" },
                        statusCode: StatusCodes.Status403Forbidden);
                }
            })
            .RequireAuthorization()
            .RequireRateLimiting(MetraRateLimiting.PolicyRead)
            .WithName("GetStationObservationArchiveItem")
            .WithTags("Observations", "Archive")
            .WithSummary("Get one station-scoped historical observation");

        return endpoints;
    }
}
