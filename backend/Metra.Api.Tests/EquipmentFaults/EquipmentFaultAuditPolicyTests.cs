using Metra.Api.Features.EquipmentFaults;
using Xunit;

namespace Metra.Api.Tests.EquipmentFaults;

public sealed class EquipmentFaultAuditPolicyTests
{
    [Fact]
    public void Valid_transition_audit_entry_is_accepted()
    {
        var entry = new EquipmentFaultAuditEntry(
            Guid.NewGuid(),
            Guid.NewGuid(),
            DateTimeOffset.UtcNow,
            EquipmentFaultStatus.Submitted,
            EquipmentFaultStatus.UnderReview,
            "تمت مراجعة البلاغ.");

        Assert.Null(EquipmentFaultAuditPolicy.Validate(entry));
    }

    [Fact]
    public void Creation_audit_without_previous_status_is_accepted_only_for_submitted()
    {
        var valid = Create(previous: null, next: EquipmentFaultStatus.Submitted);
        var invalid = Create(previous: null, next: EquipmentFaultStatus.UnderReview);

        Assert.Null(EquipmentFaultAuditPolicy.Validate(valid));
        Assert.Equal("invalid_audit_transition", EquipmentFaultAuditPolicy.Validate(invalid));
    }

    [Fact]
    public void Null_entry_is_rejected()
    {
        Assert.Equal("invalid_audit_entry", EquipmentFaultAuditPolicy.Validate(null));
    }

    [Theory]
    [InlineData(true, false)]
    [InlineData(false, true)]
    [InlineData(false, false)]
    public void Missing_fault_or_actor_identity_is_rejected(bool emptyFault, bool emptyActor)
    {
        var entry = Create(
            faultId: emptyFault ? Guid.Empty : Guid.NewGuid(),
            actorId: emptyActor ? Guid.Empty : Guid.NewGuid());

        Assert.Equal("invalid_audit_identity", EquipmentFaultAuditPolicy.Validate(entry));
    }

    [Fact]
    public void Undefined_status_is_rejected()
    {
        var entry = Create(previous: (EquipmentFaultStatus)999);

        Assert.Equal("invalid_audit_status", EquipmentFaultAuditPolicy.Validate(entry));
    }

    [Theory]
    [InlineData(EquipmentFaultStatus.Submitted, EquipmentFaultStatus.Submitted)]
    [InlineData(EquipmentFaultStatus.Closed, EquipmentFaultStatus.InProgress)]
    [InlineData(EquipmentFaultStatus.Rejected, EquipmentFaultStatus.UnderReview)]
    public void Disallowed_transition_is_rejected(
        EquipmentFaultStatus previous, EquipmentFaultStatus next)
    {
        var entry = Create(previous: previous, next: next);

        Assert.Equal("invalid_audit_transition", EquipmentFaultAuditPolicy.Validate(entry));
    }

    [Fact]
    public void Default_timestamp_is_rejected()
    {
        var entry = Create(occurredAt: DateTimeOffset.MinValue);

        Assert.Equal("invalid_audit_timestamp", EquipmentFaultAuditPolicy.Validate(entry));
    }

    [Theory]
    [InlineData("")]
    [InlineData("سبب")]
    [InlineData(" سبب توضيحي")]
    [InlineData("سبب توضيحي ")]
    public void Invalid_reason_is_rejected(string reason)
    {
        var entry = Create(reason: reason);

        Assert.Equal("invalid_audit_reason", EquipmentFaultAuditPolicy.Validate(entry));
    }

    [Fact]
    public void Reason_length_boundaries_are_accepted()
    {
        var minimum = Create(reason: "12345");
        var maximum = Create(reason: new string('x', 1000));

        Assert.Null(EquipmentFaultAuditPolicy.Validate(minimum));
        Assert.Null(EquipmentFaultAuditPolicy.Validate(maximum));
    }

    private static EquipmentFaultAuditEntry Create(
        Guid? faultId = null,
        Guid? actorId = null,
        DateTimeOffset? occurredAt = null,
        EquipmentFaultStatus? previous = EquipmentFaultStatus.Submitted,
        EquipmentFaultStatus next = EquipmentFaultStatus.UnderReview,
        string reason = "تمت مراجعة البلاغ.") =>
        new(
            faultId ?? Guid.NewGuid(),
            actorId ?? Guid.NewGuid(),
            occurredAt ?? DateTimeOffset.UtcNow,
            previous,
            next,
            reason);
}
