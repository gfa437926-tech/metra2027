namespace Metra.Api.Features.EquipmentFaults;

/// <summary>
/// A deliberately small list projection. Persistence adapters must populate it
/// only from records belonging to the supplied station scope.
/// </summary>
public sealed record EquipmentFaultListItem(
    Guid FaultId,
    Guid StationId,
    string Category,
    string EquipmentName,
    EquipmentFaultSeverity Severity,
    EquipmentFaultStatus Status,
    DateTimeOffset OccurredAt);

public sealed record EquipmentFaultListPage(
    IReadOnlyList<EquipmentFaultListItem> Items,
    long TotalCount,
    int Page,
    int PageSize);

/// <summary>
/// Detail projection returned only after the adapter applies both identifiers
/// in the same read predicate.
/// </summary>
public sealed record EquipmentFaultDetail(
    Guid FaultId,
    Guid StationId,
    Guid ReporterId,
    string Category,
    string EquipmentName,
    string Description,
    EquipmentFaultSeverity Severity,
    EquipmentFaultStatus Status,
    DateTimeOffset OccurredAt);

/// <summary>
/// Read ports are intentionally station-scoped. Implementations must apply the
/// station predicate and every supplied filter identically to both the page query
/// and its total count before ordering, offset, or limit. Ordering must be stable:
/// append FaultId as a unique tie-breaker for equal OccurredAt values. A page's
/// metadata must describe the exact requested window, and each row must echo the
/// persisted station identifier so the application boundary can verify scope.
/// Detail reads must use one predicate containing both FaultId and StationId.
/// </summary>
public interface IEquipmentFaultReadStore
{
    Task<EquipmentFaultListPage> GetPageAsync(
        Guid stationId,
        EquipmentFaultListQuery query,
        EquipmentFaultListWindow window,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Must query by faultId AND stationId in the same predicate, returning null
    /// for either miss without revealing whether a cross-station record exists.
    /// </summary>
    Task<EquipmentFaultDetail?> GetDetailAsync(
        Guid faultId,
        Guid stationId,
        CancellationToken cancellationToken = default);
}

public enum EquipmentFaultReadResultCode
{
    Success,
    InvalidRequest,
    NotFoundOrWrongStation,
    Forbidden,
    DependencyFailure
}

public sealed record EquipmentFaultListReadResult(
    EquipmentFaultReadResultCode Code,
    EquipmentFaultListPage? Page = null);

public sealed record EquipmentFaultDetailReadResult(
    EquipmentFaultReadResultCode Code,
    EquipmentFaultDetail? Detail = null);

/// <summary>
/// Fail-closed read orchestration. stationId must be resolved from trusted
/// authenticated server context by the future handler, never from a query filter.
/// </summary>
public sealed class EquipmentFaultReadService(
    Metra.Api.Security.IStationAuthorizationService authorization,
    IEquipmentFaultReadStore store)
{
    public async Task<EquipmentFaultListReadResult> GetPageAsync(
        Guid userId,
        Guid stationId,
        EquipmentFaultListQuery? query,
        CancellationToken cancellationToken = default)
    {
        if (userId == Guid.Empty || stationId == Guid.Empty ||
            !EquipmentFaultListQueryPolicy.TryNormalize(query, out var window))
            return new(EquipmentFaultReadResultCode.InvalidRequest);

        var allowed = await EquipmentFaultAuthorization.HasStationPermissionAsync(
            authorization, userId, stationId, "equipment_fault.read", cancellationToken);
        if (!allowed)
            return new(EquipmentFaultReadResultCode.Forbidden);

        try
        {
            var page = await store.GetPageAsync(
                stationId, query!, window, cancellationToken);

            if (!IsValidPage(page, window, stationId))
                return new(EquipmentFaultReadResultCode.DependencyFailure);

            return new(EquipmentFaultReadResultCode.Success, page);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            return new(EquipmentFaultReadResultCode.DependencyFailure);
        }
    }

    public async Task<EquipmentFaultDetailReadResult> GetDetailAsync(
        Guid userId,
        Guid stationId,
        Guid faultId,
        CancellationToken cancellationToken = default)
    {
        if (userId == Guid.Empty || stationId == Guid.Empty || faultId == Guid.Empty)
            return new(EquipmentFaultReadResultCode.InvalidRequest);

        var allowed = await EquipmentFaultAuthorization.HasStationPermissionAsync(
            authorization, userId, stationId, "equipment_fault.read", cancellationToken);
        if (!allowed)
            return new(EquipmentFaultReadResultCode.Forbidden);

        try
        {
            var detail = await store.GetDetailAsync(faultId, stationId, cancellationToken);
            if (detail is null ||
                detail.FaultId != faultId ||
                detail.StationId != stationId)
                return new(EquipmentFaultReadResultCode.NotFoundOrWrongStation);

            if (!IsValidDetail(detail))
                return new(EquipmentFaultReadResultCode.DependencyFailure);

            return new(EquipmentFaultReadResultCode.Success, detail);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            return new(EquipmentFaultReadResultCode.DependencyFailure);
        }
    }

    private static bool IsValidPage(
        EquipmentFaultListPage? page,
        EquipmentFaultListWindow window,
        Guid expectedStationId)
    {
        if (page is null || page.Items is null ||
            page.TotalCount < page.Items.Count ||
            page.Page != window.Page ||
            page.PageSize != window.PageSize ||
            page.Items.Count > window.PageSize)
            return false;

        var seen = new HashSet<Guid>();
        foreach (var item in page.Items)
        {
            if (item is null ||
                item.FaultId == Guid.Empty ||
                item.StationId != expectedStationId ||
                !HasLength(item.Category, 2, 80) ||
                !HasLength(item.EquipmentName, 2, 120) ||
                !Enum.IsDefined(item.Severity) ||
                !Enum.IsDefined(item.Status) ||
                item.OccurredAt == default ||
                !seen.Add(item.FaultId))
                return false;
        }

        return true;
    }

    private static bool IsValidDetail(EquipmentFaultDetail detail) =>
        detail.ReporterId != Guid.Empty &&
        HasLength(detail.Category, 2, 80) &&
        HasLength(detail.EquipmentName, 2, 120) &&
        HasLength(detail.Description, 10, 4000) &&
        Enum.IsDefined(detail.Severity) &&
        Enum.IsDefined(detail.Status) &&
        detail.OccurredAt != default;

    private static bool HasLength(string? value, int min, int max) =>
        value is not null &&
        value == value.Trim() &&
        value.Length >= min &&
        value.Length <= max;
}
