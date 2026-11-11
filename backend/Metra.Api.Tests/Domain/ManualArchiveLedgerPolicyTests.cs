using Metra.Api.Domain.Archive;
using Xunit;

namespace Metra.Api.Tests.Domain;

public sealed class ManualArchiveLedgerPolicyTests
{
    private static readonly Guid Station = Guid.Parse("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
    private static readonly Guid User = Guid.Parse("11111111-1111-4111-8111-111111111111");

    [Fact]
    public void Rejects_unknown_report_kind()
    {
        var error = ManualArchiveLedgerPolicy.ValidateRequest(
            Station, User, "synoptic", new DateOnly(2026, 11, 1), new DateOnly(2026, 11, 30),
            "report.xlsx", null);
        Assert.Equal("invalid_report_kind", error);
    }

    [Fact]
    public void Rejects_inverted_period()
    {
        var error = ManualArchiveLedgerPolicy.ValidateRequest(
            Station, User, "daily", new DateOnly(2026, 11, 30), new DateOnly(2026, 11, 1),
            "report.xlsx", null);
        Assert.Equal("invalid_period_range", error);
    }

    [Fact]
    public void Duplicate_key_is_stable_for_same_logical_archive()
    {
        var a = ManualArchiveLedgerPolicy.DuplicateKey(
            Station, "Daily", new DateOnly(2026, 11, 1), new DateOnly(2026, 11, 30), " Report.XLSX ");
        var b = ManualArchiveLedgerPolicy.DuplicateKey(
            Station, "daily", new DateOnly(2026, 11, 1), new DateOnly(2026, 11, 30), "report.xlsx");
        Assert.Equal(a, b);
    }

    [Fact]
    public async Task In_memory_ledger_rejects_duplicate_confirmation()
    {
        var ledger = new Metra.Api.Features.Archive.InMemoryManualArchiveLedgerService();
        var request = new Metra.Api.Features.Archive.ManualArchiveConfirmRequest(
            "hourly", "2026-11-01", "2026-11-01", "hourly-2026-11-01.xlsx", "archived");
        var first = await ledger.ConfirmAsync(Station, User, request, CancellationToken.None);
        var second = await ledger.ConfirmAsync(Station, User, request, CancellationToken.None);
        Assert.True(first.Succeeded);
        Assert.False(second.Succeeded);
        Assert.Equal(System.Net.HttpStatusCode.Conflict, second.StatusCode);
        Assert.Equal("duplicate_archive_confirmation", second.Error);
    }

    [Fact]
    public async Task In_memory_list_and_monthly_summary_reflect_confirmations()
    {
        var ledger = new Metra.Api.Features.Archive.InMemoryManualArchiveLedgerService();
        var station = Guid.Parse("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb");
        var user = Guid.Parse("22222222-2222-4222-8222-222222222222");
        var request = new Metra.Api.Features.Archive.ManualArchiveConfirmRequest(
            "daily", "2026-11-05", "2026-11-05", "daily-05.xlsx", null);

        var created = await ledger.ConfirmAsync(station, user, request, CancellationToken.None);
        Assert.True(created.Succeeded);

        var list = await ledger.ListAsync(station, 10, CancellationToken.None);
        Assert.True(list.Succeeded);
        var rows = Assert.IsAssignableFrom<IEnumerable<ManualArchiveConfirmation>>(list.Data);
        Assert.Contains(rows, r => r.ExcelFileName == "daily-05.xlsx" && r.StationId == station);

        var summary = await ledger.MonthlySummaryAsync(station, 2026, 11, CancellationToken.None);
        Assert.True(summary.Succeeded);
        var monthly = Assert.IsType<ManualArchiveMonthlySummary>(summary.Data);
        Assert.Equal(1, monthly.ConfirmationCount);
        Assert.Contains("daily", monthly.ReportKinds);
    }

    [Fact]
    public async Task In_memory_list_does_not_leak_other_station_rows()
    {
        var ledger = new Metra.Api.Features.Archive.InMemoryManualArchiveLedgerService();
        var stationA = Guid.Parse("cccccccc-cccc-4ccc-8ccc-cccccccccccc");
        var stationB = Guid.Parse("dddddddd-dddd-4ddd-8ddd-dddddddddddd");
        var user = Guid.Parse("33333333-3333-4333-8333-333333333333");

        await ledger.ConfirmAsync(stationA, user,
            new Metra.Api.Features.Archive.ManualArchiveConfirmRequest(
                "hourly", "2026-11-01", "2026-11-01", "a.xlsx", null),
            CancellationToken.None);
        await ledger.ConfirmAsync(stationB, user,
            new Metra.Api.Features.Archive.ManualArchiveConfirmRequest(
                "hourly", "2026-11-01", "2026-11-01", "b.xlsx", null),
            CancellationToken.None);

        var listA = await ledger.ListAsync(stationA, 50, CancellationToken.None);
        var rowsA = Assert.IsAssignableFrom<IEnumerable<ManualArchiveConfirmation>>(listA.Data).ToArray();
        Assert.All(rowsA, r => Assert.Equal(stationA, r.StationId));
        Assert.DoesNotContain(rowsA, r => r.ExcelFileName == "b.xlsx");
    }
}
