using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Security;

namespace Metra.Api.Features.Observations;

public sealed record ObservationResubmitRequest(JsonElement? Payload);

public sealed record ObservationResubmitOutcome(
    bool IsConfigured,
    bool Succeeded,
    HttpStatusCode? StatusCode,
    JsonElement? Data);

public interface IObservationResubmitService
{
    bool IsConfigured { get; }

    Task<ObservationResubmitOutcome> ResubmitAsync(
        Guid userId,
        Guid stationId,
        Guid observationId,
        ObservationResubmitRequest request,
        CancellationToken cancellationToken);
}

/// <summary>
/// Calls the atomic resubmit RPC after a return-for-correction decision.
/// Identity is always the authenticated JWT subject; never a client-supplied user id.
/// </summary>
public sealed class SupabaseObservationResubmitService(
    IHttpClientFactory clients,
    IConfiguration configuration) : IObservationResubmitService
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _serviceKey = configuration["Supabase:ServiceRoleKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_serviceKey);

    public async Task<ObservationResubmitOutcome> ResubmitAsync(
        Guid userId,
        Guid stationId,
        Guid observationId,
        ObservationResubmitRequest request,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured)
            return new(false, false, null, null);

        using var message = new HttpRequestMessage(
            HttpMethod.Post,
            $"{_url!.TrimEnd('/')}/rest/v1/rpc/metra_resubmit_observation");
        message.Headers.TryAddWithoutValidation("apikey", _serviceKey);
        message.Headers.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _serviceKey);
        message.Content = JsonContent.Create(new
        {
            p_user_id = userId,
            p_station_id = stationId,
            p_observation_id = observationId,
            p_payload = request.Payload
        });

        try
        {
            using var response = await clients
                .CreateClient(nameof(SupabaseObservationResubmitService))
                .SendAsync(message, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(cancellationToken);
                return new(true, false, MapResubmitFailure(body, response.StatusCode), null);
            }

            var data = await response.Content.ReadFromJsonAsync<JsonElement>(
                cancellationToken: cancellationToken);
            return new(true, true, response.StatusCode, data);
        }
        catch (JsonException)
        {
            return new(true, false, HttpStatusCode.ServiceUnavailable, null);
        }
        catch (HttpRequestException)
        {
            return new(true, false, HttpStatusCode.ServiceUnavailable, null);
        }
        catch (TaskCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return new(true, false, HttpStatusCode.ServiceUnavailable, null);
        }
    }

    public static HttpStatusCode MapResubmitFailure(string? errorBody, HttpStatusCode fallback)
    {
        if (string.IsNullOrWhiteSpace(errorBody))
            return fallback is HttpStatusCode.Forbidden or HttpStatusCode.NotFound or HttpStatusCode.Conflict
                ? fallback
                : HttpStatusCode.ServiceUnavailable;

        if (errorBody.Contains("not_observation_owner", StringComparison.Ordinal))
            return HttpStatusCode.Forbidden;
        if (errorBody.Contains("observation_not_found", StringComparison.Ordinal))
            return HttpStatusCode.NotFound;
        if (errorBody.Contains("observation_not_in_returned_state", StringComparison.Ordinal))
            return HttpStatusCode.Conflict;
        if (errorBody.Contains("station_observation_submit_forbidden", StringComparison.Ordinal))
            return HttpStatusCode.Forbidden;
        if (errorBody.Contains("invalid_observation_payload", StringComparison.Ordinal))
            return HttpStatusCode.BadRequest;

        return fallback is >= HttpStatusCode.BadRequest and < HttpStatusCode.InternalServerError
            ? fallback
            : HttpStatusCode.ServiceUnavailable;
    }
}

public static class ObservationResubmitRequestGuard
{
    public static string? GetError(ObservationResubmitRequest? request)
    {
        if (request?.Payload is { } payload &&
            payload.ValueKind is not (JsonValueKind.Object or JsonValueKind.Null or JsonValueKind.Undefined))
            return "invalid_observation_payload";

        if (request?.Payload is { ValueKind: JsonValueKind.Object } obj &&
            obj.GetRawText().Length > 65536)
            return "invalid_observation_payload";

        return null;
    }
}

public static class ObservationResubmitEndpoints
{
    public static IEndpointRouteBuilder MapObservationResubmitEndpoints(
        this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost(
            "/api/v1/stations/{stationId:guid}/observations/{observationId:guid}/resubmit",
            async (
                Guid stationId,
                Guid observationId,
                ObservationResubmitRequest? request,
                HttpContext http,
                IObservationResubmitService resubmit,
                CancellationToken cancellationToken) =>
            {
                // Authenticated subject only — never accept a client-supplied user id.
                if (!Guid.TryParse(http.User.FindFirstValue("sub"), out var userId) || userId == Guid.Empty)
                    return Results.Unauthorized();

                var validationError = ObservationResubmitRequestGuard.GetError(request);
                if (validationError is not null)
                    return Results.BadRequest(new { error = validationError });

                if (!resubmit.IsConfigured)
                    return Results.Problem(
                        title: "Observation resubmit service unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);

                var result = await resubmit.ResubmitAsync(
                    userId,
                    stationId,
                    observationId,
                    request ?? new ObservationResubmitRequest(null),
                    cancellationToken);

                if (!result.Succeeded)
                {
                    if (result.StatusCode == HttpStatusCode.Forbidden)
                        return Results.Forbid();
                    if (result.StatusCode == HttpStatusCode.NotFound)
                        return Results.NotFound(new { error = "observation_not_found" });
                    if (result.StatusCode == HttpStatusCode.BadRequest)
                        return Results.BadRequest(new { error = "invalid_observation_payload" });
                    if (result.StatusCode == HttpStatusCode.Conflict)
                        return Results.Conflict(new { error = "observation_not_in_returned_state" });
                    return Results.Problem(
                        title: "Observation resubmit unavailable",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }

                return Results.Ok(result.Data);
            })
            .RequireStationPermission("observation.submit")
            .WithTags("Observations")
            .WithName("ResubmitStationObservation");

        return endpoints;
    }
}
