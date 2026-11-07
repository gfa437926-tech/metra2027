namespace Metra.Api.Features.EquipmentFaults;

/// <summary>
/// A deliberately small list projection. Persistence adapters must populate it
/// only from records belonging to the supplied station scope.
/// </summary>
public sealed record EquipmentFaultListItem(
    Guid FaultId,
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
/// station predicate before count, ordering, offset, or limit.
/// </summary>
public interface IEquipmentFaultReadStore
{
    Task<EquipmentFaultListPage> GetPageAsync(
        Guid stationId,
        EquipmentFaultListQuery query,
        EquipmentFaultListWindow window,
        CancellationToken cancellationToken = default);

    /// <summary>Must query by faultId AND stationId, returning null for either miss.</summary>
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

            if (page is null || page.Items is null ||
                page.TotalCount < 0 ||
                page.Page != window.Page ||
                page.PageSize != window.PageSize ||
                page.Items.Count > window.PageSize)
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
}
