using System.Net.Http.Headers;
using System.Text.Json;
using Metra.Api.Domain.Stations;

namespace Metra.Api.Features.Stations;

/// <summary>
/// Reads the normalized catalog schema with the already validated caller JWT.
/// This intentionally does not use service_role: Postgres grants/RLS remain the
/// authority for which stations the caller can see.
/// </summary>
public interface IGreenfieldStationDirectoryReader
{
    bool IsConfigured { get; }
    Task<GreenfieldStationDirectoryResult?> GetStationsAsync(
        string callerAccessToken,
        int limit,
        int offset,
        string? stationTypeCode,
        CancellationToken cancellationToken);
}

public sealed class SupabaseGreenfieldStationDirectoryReader(
    IHttpClientFactory clients,
    IConfiguration configuration) : IGreenfieldStationDirectoryReader
{
    private readonly string? _url = configuration["Supabase:Url"];
    private readonly string? _publishableKey = configuration["Supabase:PublishableKey"];

    public bool IsConfigured =>
        Uri.TryCreate(_url, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        !string.IsNullOrWhiteSpace(_publishableKey) &&
        !_publishableKey.Contains("service_role", StringComparison.OrdinalIgnoreCase);

    public async Task<GreenfieldStationDirectoryResult?> GetStationsAsync(
        string callerAccessToken,
        int limit,
        int offset,
        string? stationTypeCode,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured || string.IsNullOrWhiteSpace(callerAccessToken) ||
            limit is < 1 or > GreenfieldStationDirectoryMapper.MaximumStations ||
            offset < 0 || (stationTypeCode is not null && !IsSafeTypeCode(stationTypeCode)))
            return null;

        var select = "id,station_code,name_ar,name_en,wmo_identifier,approval_status," +
            "operational_status,elevation_m,timezone_name," +
            "station_types(type_code,name_ar,name_en)," +
            "station_locations(latitude,longitude,elevation_m,timezone_name," +
            "location_source,horizontal_accuracy_m,valid_to)";
        var query = "select=" + Uri.EscapeDataString(select) +
            "&approval_status=eq.approved" +
            "&operational_status=in.(active,temporarily_closed)" +
            "&station_types.is_active=eq.true" +
            "&station_locations.valid_to=is.null" +
            "&order=station_code.asc" +
            "&limit=" + limit +
            "&offset=" + offset;
        if (stationTypeCode is not null)
            query += "&station_types.type_code=eq." + Uri.EscapeDataString(stationTypeCode);

        using var request = new HttpRequestMessage(
            HttpMethod.Get, $"{_url!.TrimEnd('/')}/rest/v1/stations?{query}");
        request.Headers.TryAddWithoutValidation("apikey", _publishableKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", callerAccessToken);
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        request.Headers.TryAddWithoutValidation("Accept-Profile", "catalog");

        try
        {
            using var response = await clients
                .CreateClient(nameof(SupabaseGreenfieldStationDirectoryReader))
                .SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
                return null;

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
            var flattened = Flatten(document.RootElement);
            return GreenfieldStationDirectoryMapper.Map(flattened);
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
        catch (InvalidOperationException)
        {
            return null;
        }
    }

    private static JsonElement Flatten(JsonElement rows)
    {
        if (rows.ValueKind != JsonValueKind.Array)
            return rows.Clone();

        using var output = new MemoryStream();
        using (var writer = new Utf8JsonWriter(output))
        {
            writer.WriteStartArray();
            foreach (var row in rows.EnumerateArray())
            {
                if (row.ValueKind != JsonValueKind.Object)
                {
                    writer.WriteNullValue();
                    continue;
                }

                writer.WriteStartObject();
                Copy(row, writer, "id");
                Copy(row, writer, "station_code");
                Copy(row, writer, "name_ar");
                Copy(row, writer, "name_en");
                Copy(row, writer, "wmo_identifier");
                Copy(row, writer, "approval_status");
                Copy(row, writer, "operational_status");
                Copy(row, writer, "elevation_m");
                Copy(row, writer, "timezone_name");

                var type = row.TryGetProperty("station_types", out var typeElement)
                    ? typeElement : default;
                Copy(type, writer, "type_code", "station_type_code");
                Copy(type, writer, "name_ar", "station_type_name_ar");
                Copy(type, writer, "name_en", "station_type_name_en");

                var locations = row.TryGetProperty("station_locations", out var locationElement)
                    ? locationElement : default;
                if (locations.ValueKind == JsonValueKind.Array &&
                    locations.GetArrayLength() == 1)
                {
                    var location = locations[0];
                    Copy(location, writer, "latitude");
                    Copy(location, writer, "longitude");
                    Copy(location, writer, "location_source");
                    Copy(location, writer, "horizontal_accuracy_m");
                }
                else if (locations.ValueKind == JsonValueKind.Array &&
                    locations.GetArrayLength() == 0)
                {
                    writer.WriteNull("latitude");
                    writer.WriteNull("longitude");
                    writer.WriteNull("location_source");
                    writer.WriteNull("horizontal_accuracy_m");
                }
                else
                {
                    // A missing or multiplied embedded relation is not a valid
                    // current-location projection. Fail the entire page closed.
                    writer.WriteNull("latitude");
                    writer.WriteNull("longitude");
                    writer.WriteNull("location_source");
                    writer.WriteNull("horizontal_accuracy_m");
                    writer.WriteString("projection_error", "current_location_cardinality_invalid");
                }
                writer.WriteEndObject();
            }
            writer.WriteEndArray();
        }

        using var flattenedDocument = JsonDocument.Parse(output.ToArray());
        return flattenedDocument.RootElement.Clone();
    }

    private static void Copy(JsonElement source, Utf8JsonWriter writer, string property,
        string? target = null)
    {
        if (source.ValueKind == JsonValueKind.Object &&
            source.TryGetProperty(property, out var value))
        {
            writer.WritePropertyName(target ?? property);
            value.WriteTo(writer);
        }
        else if (target is not null)
        {
            writer.WriteNull(target);
        }
    }

    private static bool IsSafeTypeCode(string value) =>
        value.Length is > 0 and <= 64 &&
        value.All(character => char.IsAsciiLetterOrDigit(character) ||
            character is '_' or '-');
}
