using Microsoft.AspNetCore.Mvc;

namespace Metra.Api.Features.Stations;

/// <summary>
/// HTTP surface for the station catalogue. Routes are protected immediately,
/// but return 503 until the approved actor context and permission-enforcing
/// read-store implementations are registered by the application owner.
/// </summary>
public static class StationEndpoints
{
    public static void MapStationEndpoints(this WebApplication app)
    {
        var stations = app.MapGroup("/api/v1/stations")
            .WithTags("Stations")
            .RequireAuthorization();

        stations.MapGet("/", ReadCatalogueAsync)
            .WithName("ReadStationCatalogue");

        stations.MapGet("/{sourceKind}/{sourceRecordId}", ReadStationDetailAsync)
            .WithName("ReadStationDetail");
    }

    private static async Task<IResult> ReadCatalogueAsync(
        [FromQuery] StationCatalogueSourceKind? sourceKind,
        [FromQuery] string? namePrefix,
        [FromQuery] int? pageSize,
        [FromQuery] string? cursor,
        IServiceProvider services,
        CancellationToken cancellationToken)
    {
        var queryService = services.GetService<StationCatalogueQueryService>();
        if (queryService is null)
            return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);

        var result = await queryService.ReadAsync(
            new StationCatalogueQuery(sourceKind, namePrefix, pageSize ?? 50, cursor),
            cancellationToken);

        return result.Status switch
        {
            StationCatalogueReadStatus.Succeeded => Results.Ok(result.Page),
            StationCatalogueReadStatus.Unauthenticated => Results.Unauthorized(),
            StationCatalogueReadStatus.Unauthorized => Results.Forbid(),
            StationCatalogueReadStatus.InvalidQuery => Results.BadRequest(new
            {
                code = "invalid_station_query",
                message = "The station catalogue query is invalid."
            }),
            StationCatalogueReadStatus.InvalidStoreResponse =>
                Results.StatusCode(StatusCodes.Status502BadGateway),
            _ => Results.StatusCode(StatusCodes.Status500InternalServerError)
        };
    }

    private static async Task<IResult> ReadStationDetailAsync(
        string sourceKind,
        string sourceRecordId,
        IServiceProvider services,
        CancellationToken cancellationToken)
    {
        if (!Enum.TryParse<StationCatalogueSourceKind>(
                sourceKind, ignoreCase: true, out var parsedSourceKind) ||
            !Enum.IsDefined(parsedSourceKind))
        {
            return Results.BadRequest(new
            {
                code = "invalid_station_source",
                message = "The station source kind is invalid."
            });
        }

        var queryService = services.GetService<StationDetailQueryService>();
        if (queryService is null)
            return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);

        var result = await queryService.ReadAsync(
            new StationSourceKey(parsedSourceKind, sourceRecordId),
            cancellationToken);

        return result.Status switch
        {
            StationDetailReadStatus.Succeeded => Results.Ok(result.Station),
            StationDetailReadStatus.Unauthenticated => Results.Unauthorized(),
            StationDetailReadStatus.Unauthorized => Results.Forbid(),
            StationDetailReadStatus.InvalidKey => Results.BadRequest(new
            {
                code = "invalid_station_key",
                message = "The station source key is invalid."
            }),
            StationDetailReadStatus.NotFound => Results.NotFound(),
            StationDetailReadStatus.InvalidStoreResponse =>
                Results.StatusCode(StatusCodes.Status502BadGateway),
            _ => Results.StatusCode(StatusCodes.Status500InternalServerError)
        };
    }
}
