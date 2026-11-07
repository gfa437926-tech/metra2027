using Metra.Api.Features.EquipmentFaults;
using Xunit;

namespace Metra.Api.Tests.EquipmentFaults;

public sealed class EquipmentFaultListQueryPolicyTests
{
    [Fact]
    public void Valid_query_preserves_filters_and_calculates_offset()
    {
        var from = new DateTimeOffset(2026, 11, 1, 0, 0, 0, TimeSpan.Zero);
        var to = from.AddDays(2);
        var query = new EquipmentFaultListQuery(
            3, 20, EquipmentFaultStatus.InProgress,
            EquipmentFaultSeverity.High, from, to);

        Assert.True(EquipmentFaultListQueryPolicy.TryNormalize(query, out var window));
        Assert.Equal(new EquipmentFaultListWindow(3, 20, 40), window);
    }

    [Fact]
    public void Default_query_uses_documented_first_page_and_page_size()
    {
        var query = new EquipmentFaultListQuery();

        Assert.True(EquipmentFaultListQueryPolicy.TryNormalize(query, out var window));
        Assert.Equal(new EquipmentFaultListWindow(1, 25, 0), window);
    }

    [Fact]
    public void Null_query_is_rejected_with_safe_default_window()
    {
        Assert.False(EquipmentFaultListQueryPolicy.TryNormalize(null, out var window));
        Assert.Equal(
            new EquipmentFaultListWindow(1, EquipmentFaultListQueryPolicy.DefaultPageSize, 0),
            window);
    }

    [Theory]
    [InlineData(0, 25)]
    [InlineData(-1, 25)]
    [InlineData(100001, 25)]
    [InlineData(1, 0)]
    [InlineData(1, -1)]
    [InlineData(1, 101)]
    public void Invalid_page_or_size_is_rejected(int page, int pageSize)
    {
        Assert.False(EquipmentFaultListQueryPolicy.TryNormalize(
            new EquipmentFaultListQuery(page, pageSize, null, null, null, null),
            out _));
    }

    [Fact]
    public void Maximum_page_and_size_have_bounded_offset()
    {
        Assert.True(EquipmentFaultListQueryPolicy.TryNormalize(
            new EquipmentFaultListQuery(
                EquipmentFaultListQueryPolicy.MaximumPage,
                EquipmentFaultListQueryPolicy.MaximumPageSize,
                null, null, null, null),
            out var window));

        Assert.Equal(9_999_900, window.Offset);
    }

    [Fact]
    public void Undefined_status_filter_is_rejected()
    {
        Assert.False(EquipmentFaultListQueryPolicy.TryNormalize(
            new EquipmentFaultListQuery(
                1, 25, (EquipmentFaultStatus)999, null, null, null), out _));
    }

    [Fact]
    public void Undefined_severity_filter_is_rejected()
    {
        Assert.False(EquipmentFaultListQueryPolicy.TryNormalize(
            new EquipmentFaultListQuery(
                1, 25, null, (EquipmentFaultSeverity)999, null, null), out _));
    }

    [Fact]
    public void Reversed_occurrence_range_is_rejected()
    {
        var now = DateTimeOffset.UtcNow;
        Assert.False(EquipmentFaultListQueryPolicy.TryNormalize(
            new EquipmentFaultListQuery(
                1, 25, null, null, now, now.AddSeconds(-1)), out _));
    }

    [Fact]
    public void Open_ended_occurrence_range_is_allowed()
    {
        Assert.True(EquipmentFaultListQueryPolicy.TryNormalize(
            new EquipmentFaultListQuery(
                1, 25, null, null, DateTimeOffset.UtcNow, null), out _));
    }
}
