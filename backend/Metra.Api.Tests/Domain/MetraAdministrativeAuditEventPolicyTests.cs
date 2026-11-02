using Metra.Api.Domain.Identity;
using Xunit;

namespace Metra.Api.Tests;

public sealed class MetraAdministrativeAuditEventPolicyTests
{
    private static readonly DateTimeOffset Occurred = new(2026, 11, 2, 3, 0, 0, TimeSpan.Zero);

    [Fact]
    public void Accepts_well_formed_immutable_audit_fact()
    {
        var result = MetraAdministrativeAuditEventPolicy.Validate(ValidEvent());

        Assert.True(result.IsValid);
        Assert.Equal("audit_event_valid", result.Code);
    }

    [Fact]
    public void Rejects_missing_event()
    {
        var result = MetraAdministrativeAuditEventPolicy.Validate(null);

        Assert.False(result.IsValid);
        Assert.Equal("audit_event_required", result.Code);
    }

    [Theory]
    [InlineData("", "audit_identifier_invalid")]
    [InlineData(" event-1", "audit_identifier_invalid")]
    [InlineData("event-1\n", "audit_identifier_invalid")]
    public void Rejects_invalid_identifiers(string eventId, string expectedCode)
    {
        var result = MetraAdministrativeAuditEventPolicy.Validate(
            ValidEvent() with { EventId = eventId });

        Assert.Equal(expectedCode, result.Code);
    }

    [Theory]
    [InlineData("Account.Suspend", "audit_action_code_invalid")]
    [InlineData("account..suspend", "audit_action_code_invalid")]
    [InlineData("account.suspend.", "audit_action_code_invalid")]
    [InlineData("account suspend", "audit_action_code_invalid")]
    public void Requires_canonical_lowercase_action_codes(string action, string expectedCode)
    {
        var result = MetraAdministrativeAuditEventPolicy.Validate(
            ValidEvent() with { ActionCode = action });

        Assert.Equal(expectedCode, result.Code);
    }

    [Fact]
    public void Rejects_non_utc_timestamp()
    {
        var result = MetraAdministrativeAuditEventPolicy.Validate(
            ValidEvent() with { OccurredAtUtc = Occurred.ToOffset(TimeSpan.FromHours(3)) });

        Assert.Equal("audit_timestamp_must_be_utc", result.Code);
    }

    [Theory]
    [InlineData("")]
    [InlineData("  ")]
    [InlineData(" reason ")]
    public void Rejects_missing_or_untrimmed_reason(string reason)
    {
        var result = MetraAdministrativeAuditEventPolicy.Validate(
            ValidEvent() with { Reason = reason });

        Assert.Equal("audit_reason_invalid", result.Code);
    }

    [Fact]
    public void Rejects_oversized_reason()
    {
        var result = MetraAdministrativeAuditEventPolicy.Validate(
            ValidEvent() with { Reason = new string('r', 2001) });

        Assert.Equal("audit_reason_invalid", result.Code);
    }

    [Fact]
    public void Rejects_control_characters_in_reason_and_change_values()
    {
        var reason = MetraAdministrativeAuditEventPolicy.Validate(
            ValidEvent() with { Reason = "reason\nwith newline" });
        var value = MetraAdministrativeAuditEventPolicy.Validate(
            ValidEvent() with { NewValue = "active\tadmin" });

        Assert.Equal("audit_reason_invalid", reason.Code);
        Assert.Equal("audit_change_value_invalid", value.Code);
    }

    [Fact]
    public void Rejects_empty_change_context()
    {
        var result = MetraAdministrativeAuditEventPolicy.Validate(
            ValidEvent() with { PreviousValue = null, NewValue = null });

        Assert.Equal("audit_change_context_required", result.Code);
    }

    [Fact]
    public void Rejects_oversized_change_values()
    {
        var result = MetraAdministrativeAuditEventPolicy.Validate(
            ValidEvent() with { NewValue = new string('x', 513) });

        Assert.Equal("audit_change_value_invalid", result.Code);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public void Requires_positive_aggregate_version(long version)
    {
        var result = MetraAdministrativeAuditEventPolicy.Validate(
            ValidEvent() with { AggregateVersion = version });

        Assert.Equal("audit_aggregate_version_invalid", result.Code);
    }

    private static MetraAdministrativeAuditEvent ValidEvent() => new(
        "event-100",
        "account-20",
        "admin-7",
        "account.lifecycle.suspend",
        "account",
        "account-20",
        "active",
        "suspended",
        Occurred,
        "Security review",
        "request-900",
        4);
}
