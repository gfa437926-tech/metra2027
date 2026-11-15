using Metra.Api.Features.Records;
using Xunit;

namespace Metra.Api.Tests.Features.Records;

public sealed class RecorderSecurityAuditEventPolicyTests
{
    private static RecorderSecurityAuditEvent ValidEvent() => new(
        Guid.NewGuid(),
        Guid.NewGuid(),
        Guid.NewGuid(),
        Guid.NewGuid(),
        "trace:metra-12345",
        "asset.accepted",
        "security_checks_passed");

    [Fact]
    public void Accepts_bounded_actor_bound_audit_event()
    {
        Assert.True(RecorderSecurityAuditEventPolicy.IsValid(ValidEvent()));
    }

    [Fact]
    public void Allows_absent_optional_capture_and_job_context()
    {
        var auditEvent = ValidEvent() with { CaptureId = null, JobId = null };

        Assert.True(RecorderSecurityAuditEventPolicy.IsValid(auditEvent));
    }

    [Fact]
    public void Rejects_missing_event_or_empty_required_identifiers()
    {
        Assert.False(RecorderSecurityAuditEventPolicy.IsValid(null));

        var valid = ValidEvent();
        Assert.False(RecorderSecurityAuditEventPolicy.IsValid(valid with { ActorSubjectId = Guid.Empty }));
        Assert.False(RecorderSecurityAuditEventPolicy.IsValid(valid with { AssetId = Guid.Empty }));
        Assert.False(RecorderSecurityAuditEventPolicy.IsValid(valid with { CaptureId = Guid.Empty }));
        Assert.False(RecorderSecurityAuditEventPolicy.IsValid(valid with { JobId = Guid.Empty }));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("trace\nforged")]
    [InlineData("trace/unsafe")]
    [InlineData("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")]
    public void Rejects_unsafe_or_unbounded_correlation_identifiers(string correlationId)
    {
        Assert.False(RecorderSecurityAuditEventPolicy.IsValid(
            ValidEvent() with { CorrelationId = correlationId }));
    }

    [Theory]
    [InlineData("asset accepted")]
    [InlineData("asset\naccepted")]
    [InlineData("")]
    public void Rejects_unsafe_or_noncanonical_transition_codes(string transition)
    {
        Assert.False(RecorderSecurityAuditEventPolicy.IsValid(
            ValidEvent() with { Transition = transition }));
    }

    [Fact]
    public void Rejects_free_form_reason_text()
    {
        Assert.False(RecorderSecurityAuditEventPolicy.IsValid(
            ValidEvent() with { ReasonCode = "scanner reported: please inspect this file" }));
    }
}
