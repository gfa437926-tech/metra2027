using System.Security.Claims;
using System.Text.Json;
using Metra.Api.Domain.Forecasting;
using Metra.Api.Features.Stations;

namespace Metra.Api.Features.Forecasting;

/// <summary>
/// Read-only forecasting centre APIs. Authenticated access to station catalogue
/// metadata and geographic comparison. Does not invent meteorological values or
/// coordinates; observation field snapshots require an approved data contract.
/// </summary>
public static class ForecastingEndpoints
{
    public static IEndpointRouteBuilder MapForecastingEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapGet("/api/v1/forecasting/stations", async (
            int? limit,
            int? offset,
            string? stationType,
            IStationDirectoryService directory,
            CancellationToken cancellationToken) =>
        {
            if (!directory.IsConfigured)
                return Results.Problem(title: "Station directory unavailable", statusCode: 503);

            var take = limit ?? 250;
            var skip = offset ?? 0;
            if (take is < 1 or > 500 || skip < 0)
                return Results.BadRequest(new { error = "invalid_pagination", maxLimit = 500 });
            if (stationType is not null &&
                stationType is not ("classic" or "automatic" or "synoptic"))
                return Results.BadRequest(new { error = "invalid_station_type" });

            var stations = await directory.GetStationsAsync(take, skip, stationType, cancellationToken);
            return stations is null
                ? Results.Problem(title: "Station directory read failed", statusCode: 503)
                : Results.Ok(new
                {
                    source = "metra_station_catalogue",
                    retrievedAtUtc = DateTimeOffset.UtcNow,
                    items = stations.Value,
                    meteorologicalSnapshot = "not_available_pending_approved_contract",
                    noteAr = "الإحداثيات والارتفاع من دليل المحطات المعتمد فقط. قيم الرصد اللحظية غير مُختلَقة في هذه المرحلة."
                });
        })
        .WithTags("Forecasting")
        .WithName("GetForecastingStations");

        endpoints.MapGet("/api/v1/forecasting/stations/{stationId:guid}", async (
            Guid stationId,
            IStationDirectoryService directory,
            CancellationToken cancellationToken) =>
        {
            if (!directory.IsConfigured)
                return Results.Problem(title: "Station directory unavailable", statusCode: 503);

            var stations = await directory.GetStationsAsync(500, 0, null, cancellationToken);
            if (stations is null)
                return Results.Problem(title: "Station directory read failed", statusCode: 503);

            if (!TryFindStation(stations.Value, stationId, out var stationJson))
                return Results.NotFound(new { error = "station_not_found" });

            var (lat, lon, elev) = ExtractGeo(stationJson);
            return Results.Ok(new
            {
                source = "metra_station_catalogue",
                retrievedAtUtc = DateTimeOffset.UtcNow,
                station = stationJson,
                latitude = lat,
                longitude = lon,
                elevationM = elev,
                dataFreshness = "catalogue_only",
                meteorologicalValues = (object?)null,
                noteAr = "لا تُعرض قيم رصد على أنها لحظية قبل اعتماد عقد لقطة الرصد للتنبؤ."
            });
        })
        .WithTags("Forecasting")
        .WithName("GetForecastingStationProfile");

        endpoints.MapPost("/api/v1/forecasting/compare", async (
            ForecastingCompareRequest? request,
            IStationDirectoryService directory,
            CancellationToken cancellationToken) =>
        {
            if (request?.StationIds is null || request.StationIds.Count is < 2 or > 12)
                return Results.BadRequest(new { error = "compare_requires_2_to_12_stations" });
            if (request.StationIds.Distinct().Count() != request.StationIds.Count)
                return Results.BadRequest(new { error = "duplicate_station_ids" });
            if (!directory.IsConfigured)
                return Results.Problem(title: "Station directory unavailable", statusCode: 503);

            var stations = await directory.GetStationsAsync(500, 0, null, cancellationToken);
            if (stations is null)
                return Results.Problem(title: "Station directory read failed", statusCode: 503);

            var selected = new List<object>();
            var geos = new List<(Guid Id, double? Lat, double? Lon, double? Elev)>();
            foreach (var id in request.StationIds)
            {
                if (!TryFindStation(stations.Value, id, out var stationJson))
                    return Results.NotFound(new { error = "station_not_found", stationId = id });
                var geo = ExtractGeo(stationJson);
                geos.Add((id, geo.Lat, geo.Lon, geo.Elev));
                selected.Add(new
                {
                    stationId = id,
                    station = stationJson,
                    latitude = geo.Lat,
                    longitude = geo.Lon,
                    elevationM = geo.Elev,
                    meteorologicalValues = (object?)null
                });
            }

            var pairs = new List<object>();
            for (var i = 0; i < geos.Count; i++)
            {
                for (var j = i + 1; j < geos.Count; j++)
                {
                    var km = GeoDistance.HaversineKm(
                        geos[i].Lat, geos[i].Lon, geos[j].Lat, geos[j].Lon);
                    double? elevDiff = geos[i].Elev is not null && geos[j].Elev is not null
                        ? geos[j].Elev - geos[i].Elev
                        : null;
                    pairs.Add(new
                    {
                        fromStationId = geos[i].Id,
                        toStationId = geos[j].Id,
                        distanceKm = km,
                        elevationDifferenceM = elevDiff,
                        distanceAvailable = km is not null
                    });
                }
            }

            return Results.Ok(new
            {
                source = "metra_station_catalogue",
                comparedAtUtc = DateTimeOffset.UtcNow,
                stations = selected,
                pairs,
                noteAr = "المقارنة الجغرافية والارتفاعية فقط. لا استنتاج سببي بين الارتفاع والعناصر الجوية."
            });
        })
        .WithTags("Forecasting")
        .WithName("CompareForecastingStations");

        return endpoints;
    }

    private static bool TryFindStation(JsonElement root, Guid stationId, out JsonElement station)
    {
        station = default;
        if (root.ValueKind != JsonValueKind.Array)
            return false;
        foreach (var item in root.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.Object)
                continue;
            if (item.TryGetProperty("id", out var idEl) &&
                Guid.TryParse(idEl.GetString(), out var id) &&
                id == stationId)
            {
                station = item.Clone();
                return true;
            }
        }
        return false;
    }

    private static (double? Lat, double? Lon, double? Elev) ExtractGeo(JsonElement station)
    {
        double? elev = null;
        if (station.TryGetProperty("elevation_m", out var elevEl) &&
            elevEl.ValueKind == JsonValueKind.Number &&
            elevEl.TryGetDouble(out var elevValue))
            elev = elevValue;

        double? lat = null, lon = null;
        if (station.TryGetProperty("station_coordinates", out var coords) &&
            coords.ValueKind == JsonValueKind.Array)
        {
            foreach (var c in coords.EnumerateArray())
            {
                if (c.ValueKind != JsonValueKind.Object)
                    continue;
                if (c.TryGetProperty("latitude", out var latEl) && latEl.TryGetDouble(out var la) &&
                    c.TryGetProperty("longitude", out var lonEl) && lonEl.TryGetDouble(out var lo) &&
                    GeoDistance.IsValidLatitude(la) && GeoDistance.IsValidLongitude(lo))
                {
                    lat = la;
                    lon = lo;
                    break;
                }
            }
        }
        return (lat, lon, elev);
    }
}

public sealed record ForecastingCompareRequest(IReadOnlyList<Guid>? StationIds);
