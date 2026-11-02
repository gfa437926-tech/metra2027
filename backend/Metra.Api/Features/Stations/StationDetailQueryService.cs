namespace Metra.Api.Features.Stations;

/// <summary>
/// A station is addressed by its source namespace and source-local identifier.
/// The key deliberately does not imply a canonical physical-station identity.
/// </summary>
public sealed record StationSourceKey(
    StationCatalogueSourceKind SourceKind,
    string SourceRecordId);

public enum StationDetailReadStatus
{
    Succeeded = 0,
    Unauthenticated = 1,
    Unauthorized = 2,
    InvalidKey = 3,
    NotFound = 4,
    InvalidStoreResponse = 5
}

public sealed record StationDetailReadResult(
    StationDetailReadStatus Status,
    StationCatalogueItem? Station = null)
{
    public bool Succeeded => Status == StationDetailReadStatus.Succeeded;
}

/// <summary>
/// Trusted source boundary for a single source-qualified station record.
/// The implementation must apply the approved station-detail read permission
/// and actor station scope in the same read operation. Return null both when
/// the record is absent and when it is outside the actor's visible scope.
/// Never resolve by display name or fall back to another source class.
/// </summary>
public interface IStationDetailReadStore
{
    Task<StationCatalogueItem?> ReadAsync(
        string actorUserId,
        StationSourceKey key,
        CancellationToken cancellationToken);
}

/// <summary>
/// Read-only source-qualified station detail query. The actor is server-derived;
/// the store enforces the approved permission and station scope on every read.
/// </summary>
public sealed class StationDetailQueryService(
    Metra.Api.Features.Identity.IAccountLifecycleActorContextProvider actorContextProvider,
    IStationDetailReadStore store)
{
    private const int MaximumIdentifierLength = 128;
    private const int MaximumDisplayNameLength = 256;

    public async Task<StationDetailReadResult> ReadAsync(
        StationSourceKey? key,
        CancellationToken cancellationToken = default)
    {
        if (key is null ||
            !Enum.IsDefined(key.SourceKind) ||
            !IsIdentifier(key.SourceRecordId))
            return new(StationDetailReadStatus.InvalidKey);

        var actorUserId = await actorContextProvider.GetCurrentActorUserIdAsync(cancellationToken);
        if (string.IsNullOrWhiteSpace(actorUserId))
            return new(StationDetailReadStatus.Unauthenticated);
        if (!IsIdentifier(actorUserId))
            return new(StationDetailReadStatus.Unauthorized);

        var station = await store.ReadAsync(actorUserId, key, cancellationToken);
        if (station is null)
            return new(StationDetailReadStatus.NotFound);
        if (!IsValidStation(station, key))
            return new(StationDetailReadStatus.InvalidStoreResponse);

        return new(StationDetailReadStatus.Succeeded, station with { });
    }

    private static bool IsValidStation(StationCatalogueItem? station, StationSourceKey key)
        => station is not null &&
           station.SourceKind == key.SourceKind &&
           string.Equals(station.SourceRecordId, key.SourceRecordId, StringComparison.Ordinal) &&
           Enum.IsDefined(station.SourceKind) &&
           IsIdentifier(station.SourceRecordId) &&
           !string.IsNullOrWhiteSpace(station.DisplayName) &&
           station.DisplayName.Length <= MaximumDisplayNameLength &&
           !station.DisplayName.Any(char.IsControl) &&
           IsOptionalTextValid(station.SourceStationType, 128) &&
           IsOptionalTextValid(station.SourceCode, 128) &&
           IsCoordinatePairValid(station.Latitude, station.Longitude) &&
           (station.ElevationMetres is null ||
            station.ElevationMetres is >= -500m and <= 10000m);

    private static bool IsIdentifier(string? value)
        => !string.IsNullOrWhiteSpace(value) &&
           value.Length <= MaximumIdentifierLength &&
           value == value.Trim() &&
           value.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '_' or '.' or ':');

    private static bool IsOptionalTextValid(string? value, int maxLength)
        => value is null || (value.Length <= maxLength && !value.Any(char.IsControl));

    private static bool IsCoordinatePairValid(decimal? latitude, decimal? longitude)
    {
        if (latitude is null || longitude is null)
            return latitude is null && longitude is null;
        return latitude is >= -90m and <= 90m &&
               longitude is >= -180m and <= 180m;
    }
}
