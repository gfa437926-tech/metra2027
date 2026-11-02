using Metra.Api.Domain.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class MetraAccessRecordPolicyTests
{
    private static readonly DateTimeOffset Start = new(2026, 1, 1, 0, 0, 0, TimeSpan.Zero);

    [Fact]
    public void Accepts_valid_global_permission_grant()
    {
        var result = MetraAccessRecordPolicy.ValidateGrant(
            new("observations.read", null, Start, Start.AddDays(1), null));

        Assert.True(result.IsValid);
    }

    [Fact]
    public void Accepts_valid_station_scoped_grant()
    {
        var result = MetraAccessRecordPolicy.ValidateGrant(
            new("observations.read", "station-1", Start, null, null));

        Assert.True(result.IsValid);
    }

    [Fact]
    public void Rejects_missing_grant()
    {
        Assert.Equal("permission_grant_required",
            MetraAccessRecordPolicy.ValidateGrant(null).Code);
    }

    [Theory]
    [InlineData("Observations.Read")]
    [InlineData("observations..read")]
    [InlineData("observations read")]
    [InlineData("")]
    public void Rejects_noncanonical_permission_code(string code)
    {
        var result = MetraAccessRecordPolicy.ValidateGrant(
            new(code, null, Start, null, null));

        Assert.Equal("permission_code_invalid", result.Code);
    }

    [Fact]
    public void Rejects_blank_or_padded_station_scope()
    {
        var blank = MetraAccessRecordPolicy.ValidateGrant(
            new("observations.read", " ", Start, null, null));
        var padded = MetraAccessRecordPolicy.ValidateGrant(
            new("observations.read", " station-1 ", Start, null, null));

        Assert.Equal("station_scope_invalid", blank.Code);
        Assert.Equal("station_scope_invalid", padded.Code);
    }

    [Fact]
    public void Rejects_non_utc_grant_timestamps()
    {
        var result = MetraAccessRecordPolicy.ValidateGrant(
            new("observations.read", null, Start.ToOffset(TimeSpan.FromHours(1)), null, null));

        Assert.Equal("access_record_time_must_be_utc", result.Code);
    }

    [Fact]
    public void Rejects_empty_or_negative_grant_window()
    {
        var result = MetraAccessRecordPolicy.ValidateGrant(
            new("observations.read", null, Start, Start, null));

        Assert.Equal("access_record_window_invalid", result.Code);
    }

    [Fact]
    public void Rejects_revocation_before_grant_start()
    {
        var result = MetraAccessRecordPolicy.ValidateGrant(
            new("observations.read", null, Start, null, Start.AddTicks(-1)));

        Assert.Equal("access_record_revocation_time_invalid", result.Code);
    }

    [Fact]
    public void Rejects_revocation_at_or_after_expiry()
    {
        var result = MetraAccessRecordPolicy.ValidateGrant(
            new("observations.read", null, Start, Start.AddDays(1), Start.AddDays(1)));

        Assert.Equal("access_record_revocation_time_invalid", result.Code);
    }

    [Fact]
    public void Accepts_valid_assignment()
    {
        var result = MetraAccessRecordPolicy.ValidateAssignment(
            new("station-1", Start, Start.AddDays(2), Start.AddDays(1)));

        Assert.True(result.IsValid);
    }

    [Fact]
    public void Rejects_missing_assignment()
    {
        Assert.Equal("station_assignment_required",
            MetraAccessRecordPolicy.ValidateAssignment(null).Code);
    }

    [Fact]
    public void Rejects_padded_or_oversized_assignment_station_id()
    {
        var padded = MetraAccessRecordPolicy.ValidateAssignment(
            new(" station-1 ", Start, null, null));
        var oversized = MetraAccessRecordPolicy.ValidateAssignment(
            new(new string('s', 129), Start, null, null));

        Assert.Equal("station_scope_invalid", padded.Code);
        Assert.Equal("station_scope_invalid", oversized.Code);
    }

    [Fact]
    public void Rejects_assignment_with_non_utc_timestamp()
    {
        var result = MetraAccessRecordPolicy.ValidateAssignment(
            new("station-1", Start, Start.AddHours(2).ToOffset(TimeSpan.FromHours(2)), null));

        Assert.Equal("access_record_time_must_be_utc", result.Code);
    }

    [Fact]
    public void Rejects_assignment_with_invalid_window()
    {
        var result = MetraAccessRecordPolicy.ValidateAssignment(
            new("station-1", Start, Start, null));

        Assert.Equal("access_record_window_invalid", result.Code);
    }
}
