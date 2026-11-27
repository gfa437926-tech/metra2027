using System.Collections.Concurrent;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Security;

namespace Metra.Api.Features.Users;

/// <summary>
/// Access context assembled only from existing PostgREST reads and existing
/// permission RPCs. No new RPC, schema, or RLS changes.
/// Permissions are never inferred from role names — each code is probed.
/// </summary>
public sealed record AccessContextStation(
    Guid StationId,
    string? RoleCode,
    IReadOnlyList<string> Permissions);

public sealed record AccessContextAuthority(
    Guid AuthorityId,
    string? RoleCode,
    IReadOnlyList<string> Permissions);

public sealed record AccessContextResponse(
    Guid UserId,
    string AccountState,
    IReadOnlyList<AccessContextStation> Stations,
    IReadOnlyList<AccessContextAuthority> Authorities);

public interface IAccessContextService
{
    bool IsConfigured { get; }
    Task<AccessContextResponse?> BuildAsync(Guid userId, CancellationToken cancellationToken);
}

public sealed class SupabaseAccessContextService(
    IHttpClientFactory clients,
    IConfiguration configuration,
    IStationAuthorizationService authorization) : IAccessContextService
{
    private const int MaximumAssignments = 100;
    private const int StationParallelism = 4;
    private const int PermissionParallelism = 3;

    private static readonly string[] StationPermissionCodes =
    [
        "observation.create",
        "observation.edit_own_draft",
        "observation.submit",
        "observation.review",
        "observation.return_for_correction",
        "observation.approve",
        "registrations.station.approve",
        "users.station.view",
        "users.station.manage"
    ];

    private static readonly string[] AuthorityPermissionCodes =
    [
        "stations.catalogue.review",
        "registrations.system.approve",
        "authority.access.review",
        "authority.access.revoke"
    ];

    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _key = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_key) &&
        authorization.IsConfigured;

    public async Task<AccessContextResponse?> BuildAsync(
        Guid userId, CancellationToken cancellationToken)
    {
        if (!IsConfigured || userId == Guid.Empty)
            return null;

        var assignments = await ReadAssignmentsAsync(userId, cancellationToken);
        var memberships = await ReadMembershipsAsync(userId, cancellationToken);
        if (assignments is null || memberships is null)
            return null;

        var stationsBag = new ConcurrentBag<AccessContextStation>();
        await Parallel.ForEachAsync(
            assignments,
            new ParallelOptions
            {
                MaxDegreeOfParallelism = StationParallelism,
                CancellationToken = cancellationToken
            },
            async (assignment, token) =>
            {
                var granted = await ProbePermissionsAsync(
                    StationPermissionCodes,
                    code => authorization.HasStationPermissionAsync(
                        userId, assignment.Id, code, token),
                    token);
                if (granted.Count > 0)
                {
                    stationsBag.Add(new AccessContextStation(
                        assignment.Id, assignment.RoleCode, granted));
                }
            });

        var authoritiesBag = new ConcurrentBag<AccessContextAuthority>();
        await Parallel.ForEachAsync(
            memberships,
            new ParallelOptions
            {
                MaxDegreeOfParallelism = StationParallelism,
                CancellationToken = cancellationToken
            },
            async (membership, token) =>
            {
                var granted = await ProbePermissionsAsync(
                    AuthorityPermissionCodes,
                    code => authorization.HasAuthorityPermissionAsync(
                        userId, membership.Id, code, token),
                    token);
                if (granted.Count > 0)
                {
                    authoritiesBag.Add(new AccessContextAuthority(
                        membership.Id, membership.RoleCode, granted));
                }
            });

        var stations = stationsBag
            .OrderBy(s => s.StationId)
            .ToArray();
        var authorities = authoritiesBag
            .OrderBy(a => a.AuthorityId)
            .ToArray();

        // accountState stays unknown until a dedicated read path exists.
        return new AccessContextResponse(userId, "unknown", stations, authorities);
    }

    private static async Task<IReadOnlyList<string>> ProbePermissionsAsync(
        IReadOnlyList<string> codes,
        Func<string, Task<bool>> probe,
        CancellationToken cancellationToken)
    {
        var granted = new ConcurrentBag<string>();
        await Parallel.ForEachAsync(
            codes,
            new ParallelOptions
            {
                MaxDegreeOfParallelism = PermissionParallelism,
                CancellationToken = cancellationToken
            },
            async (code, token) =>
            {
                if (await probe(code))
                    granted.Add(code);
            });

        // Stable order matching the probe catalogue.
        return codes.Where(granted.Contains).ToArray();
    }

    private async Task<IReadOnlyList<(Guid Id, string? RoleCode)>?> ReadAssignmentsAsync(
        Guid userId, CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;
        var encodedNow = Uri.EscapeDataString(now.ToString("O"));
        var query = "station_assignments?select=station_id,role_code" +
                    "&user_id=eq." + userId +
                    "&approval_status=eq.approved" +
                    "&valid_from=lte." + encodedNow +
                    "&or=" + Uri.EscapeDataString($"(valid_to.is.null,valid_to.gt.{now:O})") +
                    "&limit=" + (MaximumAssignments + 1);
        return await ReadScopedRowsAsync(query, "station_id", cancellationToken);
    }

    private async Task<IReadOnlyList<(Guid Id, string? RoleCode)>?> ReadMembershipsAsync(
        Guid userId, CancellationToken cancellationToken)
    {
        var now = DateTimeOffset.UtcNow;
        var encodedNow = Uri.EscapeDataString(now.ToString("O"));
        var query = "authority_memberships?select=authority_id,role_code" +
                    "&user_id=eq." + userId +
                    "&approval_status=eq.approved" +
                    "&valid_from=lte." + encodedNow +
                    "&or=" + Uri.EscapeDataString($"(valid_to.is.null,valid_to.gt.{now:O})") +
                    "&limit=" + (MaximumAssignments + 1);
        return await ReadScopedRowsAsync(query, "authority_id", cancellationToken);
    }

    private async Task<IReadOnlyList<(Guid Id, string? RoleCode)>?> ReadScopedRowsAsync(
        string query, string idProperty, CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(
            HttpMethod.Get, $"{_url!.TrimEnd('/')}/rest/v1/{query}");
        request.Headers.TryAddWithoutValidation("apikey", _key);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _key);

        try
        {
            using var response = await clients.CreateClient(nameof(SupabaseAccessContextService))
                .SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
                return null;

            var rows = await response.Content.ReadFromJsonAsync<JsonElement>(
                cancellationToken: cancellationToken);
            if (rows.ValueKind != JsonValueKind.Array ||
                rows.GetArrayLength() > MaximumAssignments)
                return null;

            var list = new List<(Guid, string?)>();
            foreach (var row in rows.EnumerateArray())
            {
                // A malformed membership row makes the complete access context
                // untrustworthy; never silently return a partial permission view.
                if (row.ValueKind != JsonValueKind.Object ||
                    !row.TryGetProperty(idProperty, out var idValue) ||
                    idValue.ValueKind != JsonValueKind.String ||
                    !Guid.TryParse(idValue.GetString(), out var id) ||
                    id == Guid.Empty)
                    return null;

                string? role = null;
                if (row.TryGetProperty("role_code", out var roleValue))
                {
                    if (roleValue.ValueKind is not (JsonValueKind.String or JsonValueKind.Null))
                        return null;

                    if (roleValue.ValueKind == JsonValueKind.String)
                    {
                        var text = roleValue.GetString();
                        if (!string.IsNullOrWhiteSpace(text))
                            role = text.Trim();
                    }
                }

                list.Add((id, role));
            }

            // Duplicate scope identifiers are ambiguous and can cause duplicate
            // permission probes or duplicate entries in the resolved context.
            if (list.Select(item => item.Item1).Distinct().Count() != list.Count)
                return null;

            return list;
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
}

public static class AccessContextEndpoints
{
    public static IEndpointRouteBuilder MapAccessContextEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/me/access-context", async (
            HttpContext http,
            IAccessContextService accessContext,
            CancellationToken cancellationToken) =>
        {
            if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId) ||
                userId == Guid.Empty)
                return Results.Unauthorized();

            if (!accessContext.IsConfigured)
                return Results.Problem(
                    title: "Access context service unavailable",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            var context = await accessContext.BuildAsync(userId, cancellationToken);
            if (context is null)
                return Results.Problem(
                    title: "Access context could not be resolved",
                    statusCode: StatusCodes.Status503ServiceUnavailable);

            return Results.Ok(new
            {
                userId = context.UserId,
                accountState = context.AccountState,
                stations = context.Stations.Select(s => new
                {
                    stationId = s.StationId,
                    roleCode = s.RoleCode,
                    permissions = s.Permissions
                }),
                authorities = context.Authorities.Select(a => new
                {
                    authorityId = a.AuthorityId,
                    roleCode = a.RoleCode,
                    permissions = a.Permissions
                })
            });
        })
        .WithTags("Users")
        .WithName("GetMyAccessContext");

        return endpoints;
    }
}
