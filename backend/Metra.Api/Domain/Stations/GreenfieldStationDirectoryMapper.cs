using System.Text.Json;

namespace Metra.Api.Domain.Stations;

public sealed record GreenfieldStationDirectoryItem(
    Guid Id,
    string StationCode,
    string NameAr,
    string NameEn,
    string? WmoIdentifier,
    string StationTypeCode,
    string StationTypeNameAr,
    string StationTypeNameEn,
    string ApprovalStatus,
    string OperationalStatus,
    decimal? Latitude,
    decimal? Longitude,
    decimal? ElevationMetres,
    string? TimezoneName,
    string? LocationSource,
    decimal? HorizontalAccuracyMetres);

public sealed record GreenfieldStationDirectoryIssue(int Index, string Code);

public sealed record GreenfieldStationDirectoryResult(
    bool Succeeded,
    IReadOnlyList<GreenfieldStationDirectoryItem> Stations,
    IReadOnlyList<GreenfieldStationDirectoryIssue> Issues);

/// <summary>
/// Maps the flat, caller-authorized stations.directory.v1 projection.
/// This is deliberately persistence-provider neutral: it does not query Supabase,
/// infer actor authority, or grant access to any station.
/// </summary>
public static class GreenfieldStationDirectoryMapper
{
    public const int MaximumStations = 500;

    private static readonly HashSet<string> AllowedProperties = new(StringComparer.Ordinal)
    {
        "id", "station_code", "name_ar", "name_en", "wmo_identifier",
        "station_type_code", "station_type_name_ar", "station_type_name_en",
        "approval_status", "operational_status", "latitude", "longitude",
        "elevation_m", "timezone_name", "location_source", "horizontal_accuracy_m"
    };

    public static GreenfieldStationDirectoryResult Map(JsonElement rows)
    {
        if (rows.ValueKind != JsonValueKind.Array)
            return Failure("station_projection_must_be_array");

        if (rows.GetArrayLength() > MaximumStations)
            return Failure("station_projection_count_out_of_range");

        var mapped = new List<GreenfieldStationDirectoryItem>(rows.GetArrayLength());
        var issues = new List<GreenfieldStationDirectoryIssue>();
        var stationIds = new HashSet<Guid>();
        var stationCodes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var index = 0;

        foreach (var row in rows.EnumerateArray())
        {
            if (row.ValueKind != JsonValueKind.Object ||
                row.EnumerateObject().Any(property => !AllowedProperties.Contains(property.Name)))
            {
                issues.Add(new(index, "station_projection_shape_invalid"));
                index++;
                continue;
            }

            if (!TryRequiredGuid(row, "id", out var id) ||
                !TryRequiredString(row, "station_code", out var code) ||
                !TryRequiredString(row, "name_ar", out var nameAr) ||
                !TryRequiredString(row, "name_en", out var nameEn) ||
                !TryRequiredString(row, "station_type_code", out var typeCode) ||
                !TryRequiredString(row, "station_type_name_ar", out var typeNameAr) ||
                !TryRequiredString(row, "station_type_name_en", out var typeNameEn) ||
                !TryRequiredString(row, "approval_status", out var approval) ||
                !TryRequiredString(row, "operational_status", out var operational))
            {
                issues.Add(new(index, "station_projection_required_field_invalid"));
                index++;
                continue;
            }

            if (approval != "approved" ||
                operational is not ("active" or "temporarily_closed"))
            {
                issues.Add(new(index, "station_projection_outside_operational_scope"));
                index++;
                continue;
            }

            if (!stationIds.Add(id) || !stationCodes.Add(code))
            {
                issues.Add(new(index, "station_projection_duplicate_identity"));
                index++;
                continue;
            }

            if (!TryOptionalString(row, "wmo_identifier", out var wmo) ||
                !TryOptionalString(row, "timezone_name", out var timezone) ||
                !TryOptionalString(row, "location_source", out var locationSource) ||
                !TryOptionalDecimal(row, "latitude", out var latitude) ||
                !TryOptionalDecimal(row, "longitude", out var longitude) ||
                !TryOptionalDecimal(row, "elevation_m", out var elevation) ||
                !TryOptionalDecimal(row, "horizontal_accuracy_m", out var accuracy) ||
                (latitude.HasValue != longitude.HasValue) ||
                (latitude is < -90 or > 90) ||
                (longitude is < -180 or > 180) ||
                (accuracy is < 0))
            {
                issues.Add(new(index, "station_projection_location_invalid"));
                index++;
                continue;
            }

            mapped.Add(new(
                id, code, nameAr, nameEn, wmo, typeCode, typeNameAr, typeNameEn,
                approval, operational, latitude, longitude, elevation, timezone,
                locationSource, accuracy));
            index++;
        }

        return issues.Count == 0
            ? new(true, mapped, Array.Empty<GreenfieldStationDirectoryIssue>())
            : new(false, Array.Empty<GreenfieldStationDirectoryItem>(), issues);

        static GreenfieldStationDirectoryResult Failure(string code) =>
            new(false, Array.Empty<GreenfieldStationDirectoryItem>(),
                [new(-1, code)]);
    }

    private static bool TryRequiredGuid(JsonElement row, string name, out Guid value)
    {
        value = default;
        return row.TryGetProperty(name, out var element) &&
            element.ValueKind == JsonValueKind.String &&
            element.TryGetGuid(out value) && value != Guid.Empty;
    }

    private static bool TryRequiredString(JsonElement row, string name, out string value)
    {
        value = string.Empty;
        if (!row.TryGetProperty(name, out var element) ||
            element.ValueKind != JsonValueKind.String ||
            string.IsNullOrWhiteSpace(element.GetString()))
            return false;
        value = element.GetString()!;
        return value == value.Trim() && value.Length <= 256 && !value.Any(char.IsControl);
    }

    private static bool TryOptionalString(JsonElement row, string name, out string? value)
    {
        value = null;
        if (!row.TryGetProperty(name, out var element) || element.ValueKind == JsonValueKind.Null)
            return true;
        if (element.ValueKind != JsonValueKind.String)
            return false;
        var candidate = element.GetString();
        if (candidate is null || candidate.Length > 256 || candidate.Any(char.IsControl))
            return false;
        value = candidate;
        return true;
    }

    private static bool TryOptionalDecimal(JsonElement row, string name, out decimal? value)
    {
        value = null;
        if (!row.TryGetProperty(name, out var element) || element.ValueKind == JsonValueKind.Null)
            return true;
        if (element.ValueKind != JsonValueKind.Number || !element.TryGetDecimal(out var parsed))
            return false;
        value = parsed;
        return true;
    }
}
