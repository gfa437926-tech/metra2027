namespace Metra.Api.Features.EquipmentFaults;

/// <summary>
/// Bounds list-query inputs before they reach a persistence adapter.
/// Station scope must still be derived from the authenticated principal and
/// enforced by the adapter; this policy does not authorize or filter records.
/// </summary>
public enum EquipmentFaultListSort
{
    OccurredAtDescending,
    OccurredAtAscending
}

public sealed record EquipmentFaultListQuery(
    int Page,
    int PageSize,
    EquipmentFaultStatus? Status,
    EquipmentFaultSeverity? Severity,
    DateTimeOffset? OccurredFrom,
    DateTimeOffset? OccurredTo,
    EquipmentFaultListSort Sort = EquipmentFaultListSort.OccurredAtDescending);

public sealed record EquipmentFaultListWindow(int Page, int PageSize, int Offset);

public static class EquipmentFaultListQueryPolicy
{
    public const int DefaultPageSize = 25;
    public const int MaximumPageSize = 100;
    public const int MaximumPage = 100_000;

    public static bool TryNormalize(
        EquipmentFaultListQuery? query,
        out EquipmentFaultListWindow window)
    {
        window = new EquipmentFaultListWindow(1, DefaultPageSize, 0);

        if (query is null ||
            query.Page is < 1 or > MaximumPage ||
            query.PageSize is < 1 or > MaximumPageSize)
            return false;

        if (query.Status is { } status && !Enum.IsDefined(status))
            return false;

        if (query.Severity is { } severity && !Enum.IsDefined(severity))
            return false;

        if (!Enum.IsDefined(query.Sort))
            return false;

        if (query.OccurredFrom is { } from &&
            query.OccurredTo is { } to && from > to)
            return false;

        // The page ceiling and page-size ceiling keep this multiplication bounded.
        var offset = checked((query.Page - 1) * query.PageSize);
        window = new EquipmentFaultListWindow(query.Page, query.PageSize, offset);
        return true;
    }
}
