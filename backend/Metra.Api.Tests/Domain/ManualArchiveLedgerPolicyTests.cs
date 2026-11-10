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
}
